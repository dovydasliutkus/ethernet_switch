## Notes 
[integration] top-level (fcs_control)has to make sure nothing is written into data_fifo and crc_calculator if data_fifo is full. If conditional on input

[future]  We assume that i_rx_ctrl behaves correctly (no glitches). However if a glitch were to happen it wouldn't cause system failure in the PAYLOAD stage, but it would crash if it happened in DST_MAC or SRC_MAC. As status and length FIFOs are only written in PAYLOAD. TODO Maybe add writing to FIFOs in the global abort conditional. Michael said not to worry about this in the beginning.

[testing:mac_learner] When deciding whether to create new entry the MAC Learner should check if the src_mac AND src port are the same. CASE: Port0 is unplugged and then plugged into Port2. The client will send something so the MAC Learner should be able to rewrite the look-up entry if the port changes. 

[testing:fcs_control] The FIFOs in `fcs_control` should never fill up. Monitor `fifo_full` signals in the big test.

[testing:crossbar] The `crossbar` should check packet length before writing it into its FIFOs. CASE: All input ports streaming to one output port - The crossbar must take only full packets and not take partial packets which will make it transmit nothing.

## TODO
- Add two dff synchronizer for reset
- Adjust block diagrams to fit the real thing
- Debug switch on fpga with 

---

## 2026-04-08
### Did

- Changed data_fifo size 4096→2048 and status/length sizes to fit for that. Adjusted fcs_control/README.md. The change was Michael's suggestion - now the data fifo fits one max size packet 1518 byte plus ~500 bytes of buffer room.
- Created FIFOs for SRC and DST mac addresses.
- Integrate SRC and DST FIFOs into crc_calculator and update the tb.


### Next
- Change the block diagram to include src and dst FIFOs.

## 2026-04-15
### Did
- Implemented `output_control.sv`
- Implemented `fcs_control.sv` to integrate the components.
- TESTED `fcs_control.sv`:
    - Sent single packet
    - Sent two packets in parallel

## TODO
- Send packet with bad CRC

## 2026-04-22
### Did
- Fixed reset to be active-low in all modules (currently mixed sync and async)
- Got direct connected example to work on DE-4 FPGA. Needed to set Ethernet IP to static. And enable a rule in the Windows firewall.

## Setup for PING

1. Set a static IP. See picture below.


![Set IP to static](../figures/set_static_eth_IP.png)

2. Enable the following `Inbound Rules` in the `Windows Defender Firewall`

![Firewall rule to enable ping](../figures/firewall_rule_for_ping.png)

3. Set a MAC address to a static IP (so the computer knows what dst_mac to use when pinging)

Daniel's IP below
```
arp -s 192.168.1.3 00-E0-4C-68-00-93
```

Get the IP by using
```
ipconfig /all
```
MAKE sure it's the MAC address from Ethernet and not virtual Ethernet or WSL Ethernet
To lists IPs and correspondig MACs
```
arp -a 
```