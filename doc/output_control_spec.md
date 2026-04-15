# `output_control.sv` — Specification

## 1. Purpose

`output_control` is the per-port outbound controller of the 1 Gb Ethernet
switch. It sits between the four per-port inbound FIFO sets and the
crossbar. Its responsibilities are:

1. Detect completed frames waiting in any of the four per-port status
   FIFOs.
2. For valid frames, resolve the destination port by querying the shared
   MAC learner.
3. For invalid (corrupted) frames, silently drain them from the data
   FIFO without involving the MAC learner or the crossbar.
4. Stream valid frames to the crossbar while preserving non-blocking
   behaviour: up to four frames may be in flight simultaneously, one per
   inbound port.
5. Preserve in-order delivery of frames arriving on the same inbound
   port (Requirement 5 — no reordering within a flow).

## 2. Interfaces

### 2.1 Clock and reset

| Signal    | Dir | Width | Description                   |
|-----------|-----|-------|-------------------------------|
| `i_clk`   | in  | 1     | System clock                  |
| `i_reset` | in  | 1     | Synchronous, active-high reset |

### 2.2 Inbound FIFO read side (per port, indexed 0–3)

| Signal              | Dir | Width  | Description                                              |
|---------------------|-----|--------|----------------------------------------------------------|
| `i_status_empty`    | in  | 4      | Bit `p` high when port `p`'s status FIFO is empty        |
| `i_valid`           | in  | 4  | Status FIFO head for each port (`1` = good, `0` = drop).  |
| `i_src_mac`         | in  | 4 × 48 | Source-MAC FIFO head for each port                       |
| `i_dst_mac`         | in  | 4 × 48 | Destination-MAC FIFO head for each port                  |
| `i_packet_length`   | in  | 4 × 11 | Length FIFO head for each port, in bytes (64–1518)       |
| `o_status_ren`      | out | 4      | One-cycle pop pulse for each port's status FIFO          |
| `o_length_ren`      | out | 4      | One-cycle pop pulse for each port's length FIFO          |
| `o_srcmac_ren`      | out | 4      | One-cycle pop pulse for each port's source-MAC FIFO      |
| `o_dstmac_ren`      | out | 4      | One-cycle pop pulse for each port's destination-MAC FIFO |
| `o_datafifo_ren`    | out | 4      | Per-port data-FIFO read enable, held high for `length` cycles |

All four metadata FIFOs (status, length, srcmac, dstmac) are popped
together — one cycle per frame, at the moment the frame is committed to
either the transmission path or the drop path.

### 2.3 MAC learner interface (shared)

| Signal      | Dir | Width | Description                                          |
|-------------|-----|-------|------------------------------------------------------|
| `o_valid`   | out | 1     | Request valid, one-cycle pulse                       |
| `o_src_mac` | out | 48    | Source MAC for learning                              |
| `o_dst_mac` | out | 48    | Destination MAC to look up                           |
| `i_done`    | in  | 1     | Response valid, one-cycle pulse                      |
| `i_dst_port`| in  | 4     | One-hot destination port (multi-bit = flood/broadcast)|

Only one request may be outstanding at a time. A new request may be
issued on the same cycle that `i_done` is asserted for the previous
request (back-to-back pipelining allowed).

### 2.4 Crossbar interface (per port)

| Signal             | Dir | Width  | Description                                                   |
|--------------------|-----|--------|---------------------------------------------------------------|
| `o_packet_valid`   | out | 4      | Held high for the full duration of the frame transmission    |
| `o_dst_port`       | out | 4 × 4  | One-hot destination port, held for the full duration of `o_packet_valid[p]` |
| `o_packet_length`  | out | 4 × 11 | Frame length in bytes, held for the full duration of `o_packet_valid[p]` |

The crossbar is assumed to handle destination contention internally; this
module does not serialize transmissions that target the same egress port.

## 3. Behaviour

### 3.1 Arbitration — round-robin for MAC learner access

A single 2-bit `rr_ptr` register selects the next candidate port. Each
cycle the module scans ports starting at `rr_ptr` in rotating order and
picks the first port `p` that satisfies all of:

- `i_status_empty[p] == 0` (a frame is waiting)
- `busy[p] == 0` (the port is not already transmitting or draining)
- The MAC learner is idle (no outstanding request)

When a port is selected, `rr_ptr` advances to `p + 1` (mod 4) on the
next cycle, guaranteeing fairness under sustained backlog.

Round-robin is applied **only** to MAC-learner access. Once a port is
transmitting, it runs in parallel with the other ports and does not
block the arbiter.

### 3.2 Valid-frame path

1. **Arbitration wins.** Port `p` is selected.
2. **MAC learner request.** `o_valid` is asserted for one cycle,
   `o_src_mac`/`o_dst_mac` driven from port `p`'s FIFO heads.
3. **Wait for response.** The module waits for `i_done`. When it
   asserts, `i_dst_port` is latched into the port's per-port state.
4. **Pop metadata.** `o_status_ren[p]`, `o_length_ren[p]`,
   `o_srcmac_ren[p]`, and `o_dstmac_ren[p]` all pulse for one cycle.
   The length value is latched into a `remaining[p]` countdown
   register.
5. **Start transmission.**
   - `o_packet_valid[p]` is asserted.
   - `o_dst_port[p]` and `o_packet_length[p]` are driven for the
     entire duration of `o_packet_valid[p]`.
   - `o_datafifo_ren[p]` is asserted.
6. **Stream.** `o_packet_valid[p]`, `o_datafifo_ren[p]`,
   `o_dst_port[p]`, and `o_packet_length[p]` stay high for `length`
   consecutive cycles. `remaining[p]` counts down.
7. **Finish.** When `remaining[p]` reaches zero, `o_packet_valid[p]`
   and `o_datafifo_ren[p]` deassert, and `busy[p]` clears. The port is
   available for arbitration again on the next cycle.

### 3.3 Drop path (invalid frame)

When the arbiter selects a port `p` whose `i_valid[p] == 0` at the
status FIFO head:

1. **No MAC learner request.** `o_valid` is not asserted for this
   frame.
2. **Pop metadata.** `o_status_ren[p]`, `o_length_ren[p]`,
   `o_srcmac_ren[p]`, and `o_dstmac_ren[p]` all pulse for one cycle.
   Length is latched into `remaining[p]`.
3. **Drain data FIFO.** `o_datafifo_ren[p]` is asserted for `length`
   cycles to discard the corrupted frame bytes. `i_packet_length`
   includes the 4-byte FCS, so the full on-wire frame is drained.
4. **`o_packet_valid[p]` stays low** throughout — the crossbar never
   sees the dropped frame.

### 3.4 Concurrency rules

- Up to four frames may be in flight simultaneously (one per inbound
  port).
- Only the MAC learner is a serialization point; everything downstream
  is per-port.
- A port is eligible for re-arbitration the cycle after its
  transmission (or drain) completes.
- Frames from the same inbound port are always serviced in FIFO order,
  satisfying the no-reordering requirement.

## 4. Internal state

| Register           | Width | Description                                 |
|--------------------|-------|---------------------------------------------|
| `rr_ptr`           | 2     | Round-robin pointer                         |
| `busy[p]`          | 1     | Port `p` is transmitting or draining        |
| `dropping[p]`      | 1     | Current in-flight frame on port `p` is a drop |
| `remaining[p]`     | 11    | Byte countdown for port `p`                 |
| `dst_port_reg[p]`  | 4     | Latched destination (one-hot) for port `p`, held for full transmission |
| `length_reg[p]`    | 11    | Latched length for port `p`, held for full transmission |

### 4.1 MAC-learner mini-FSM

```
IDLE  -> (arbitration wins, valid frame) -> REQ
REQ   -> (always)                        -> WAIT
WAIT  -> (i_done)                        -> IDLE
```

On `i_done`, the selected port transitions from "awaiting learner" to
"transmitting", and the FSM returns to IDLE ready for the next port.
Back-to-back issue is allowed: IDLE can transition to REQ on the same
cycle `i_done` arrives.

## 5. Timing summary (in cycles)

| Event                               | Cycle(s)                         |
|-------------------------------------|----------------------------------|
| Arbitration + request issue         | 1                                |
| MAC learner latency                 | 2 (black-box)                  |
| Metadata pop (status, length)       | 1 (coincident with tx start)     |
| Frame transmission                  | `length` cycles                  |
| Minimum gap between frames on one port | 1 `o_packet_valid` must go low for one cycle so the crossbar sees the frame boundary)     |

## 6. Resolved assumptions

1. **MAC FIFO pops:** handled by this module via `o_srcmac_ren` /
   `o_dstmac_ren`, pulsed in the same cycle as `o_status_ren` /
   `o_length_ren`.
2. **Crossbar back-pressure:** none. The crossbar always accepts data
   at line rate, so `o_datafifo_ren` and the `remaining` countdown
   never need to stall.
3. **`i_packet_length`:** full on-wire frame length *including* the
   4-byte FCS, so the data FIFO is drained exactly `length` times for
   both the transmission and drop paths.
