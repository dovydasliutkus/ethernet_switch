module output_control (
    input   logic  i_clk,
    input   logic  i_reset,   // Synchronous active-low

    // Ingress FIFO metadata read side (per port, indexed 0-3)
    input   logic [47:0] i_src_mac          [3:0],
    input   logic [47:0] i_dst_mac          [3:0],
    input   logic [10:0] i_packet_length    [3:0],
    input   logic [3:0]  i_valid,
    input   logic [3:0]  i_status_empty,

    output  logic [3:0]  o_status_ren,
    output  logic [3:0]  o_length_ren,
    output  logic [3:0]  o_srcmac_ren,
    output  logic [3:0]  o_dstmac_ren,

    // Data FIFO read enable (held high for `length` cycles)
    output  logic [3:0]  o_datafifo_ren,

    // MAC learner interface (shared, one request at a time)
    output  logic        o_valid,
    output  logic [3:0]  o_src_port,  // one-hot source port for split-horizon
    output  logic [47:0] o_src_mac,
    output  logic [47:0] o_dst_mac,
    input   logic        i_done,
    input   logic [3:0]  i_dst_port,

    // Crossbar interface (per port)
    output  logic [3:0]  o_packet_valid,
    output  logic [3:0]  o_dst_port      [3:0],
    output  logic [10:0] o_packet_length [3:0]
);

    typedef enum logic [1:0] {MAC_IDLE, MAC_REQ, MAC_WAIT} mac_state_t;
    mac_state_t mac_state;

    logic [1:0] arb_port;
    logic       arb_found;
    logic [1:0] p;
    logic [1:0]  rr_ptr;
    logic [1:0]  sel_port;       // port currently going through MAC learner
    logic [3:0]  busy;           // port is transmitting or draining
    logic [3:0]  dropping;       // current frame on port p is a drop
    logic [10:0] remaining  [3:0];
    logic [3:0]  dst_port_r [3:0];
    logic [10:0] length_r   [3:0];

    // ----------------------------------------------------------------
    // Sequential logic
    // ----------------------------------------------------------------
    always_ff @(posedge i_clk) begin
        if (!i_reset) begin
            mac_state <= MAC_IDLE;
            rr_ptr    <= '0;
            sel_port  <= '0;
            busy      <= '0;
            dropping  <= '0;
            for (int p = 0; p < 4; p++) begin
                remaining[p]  <= '0;
                dst_port_r[p] <= '0;
                length_r[p]   <= '0;
            end
        end else begin
            // ---- MAC FSM ----
            case (mac_state)
                MAC_IDLE: begin
                    if (arb_found) begin
                        rr_ptr <= arb_port + 2'b01; // increment input port pointer for fair RR
                        if (i_valid[arb_port]) begin
                            // Valid frame: issue MAC lookup next cycle
                            sel_port  <= arb_port;
                            mac_state <= MAC_REQ;
                        end else begin
                            // Drop frame: begin data_fifo drain without MAC lookup
                            busy[arb_port]      <= 1'b1;
                            dropping[arb_port]  <= 1'b1;
                            remaining[arb_port] <= i_packet_length[arb_port]; // Register packet length
                            // mac_state stays MAC_IDLE
                        end
                    end
                end

                MAC_REQ: begin
                    mac_state <= MAC_WAIT;
                end

                MAC_WAIT: begin
                    if (i_done) begin
                        busy[sel_port]       <= 1'b1;
                        dropping[sel_port]   <= 1'b0;
                        dst_port_r[sel_port] <= i_dst_port;
                        length_r[sel_port]   <= i_packet_length[sel_port];
                        remaining[sel_port]  <= i_packet_length[sel_port];
                        mac_state            <= MAC_IDLE;
                    end
                end

                default: mac_state <= MAC_IDLE;
            endcase

            // ---- Per-port byte countdown ----
            // Invariant: busy[p] == 1 implies remaining[p] >= 1
            for (int p = 0; p < 4; p++) begin
                if (busy[p]) begin
                    if (remaining[p] == 11'd1) begin
                        busy[p]      <= 1'b0;
                        dropping[p]  <= 1'b0;
                        remaining[p] <= '0;
                    end else begin
                        remaining[p] <= remaining[p] - 11'd1;
                    end
                end
            end
        end
    end

    // ----------------------------------------------------------------
    // Round-robin arbitration (combinatorial)
    // Scans 4 ports starting at rr_ptr; selects first with
    //   !i_status_empty[p] && !busy[p] (non empty status FIFO & not busy)
    // Only valid when mac_state == MAC_IDLE.
    // ----------------------------------------------------------------

    always_comb begin
        arb_port  = '0;
        arb_found = 1'b0;
        for (int i = 0; i < 4; i++) begin
            p = rr_ptr + 2'(i);
            if (!arb_found && !i_status_empty[p] && !busy[p]) begin
                arb_port  = p;
                arb_found = 1'b1;
            end
        end
    end

    // ----------------------------------------------------------------
    // Combinatorial outputs (MAC learner + metadata pop pulses)
    // ----------------------------------------------------------------
    always_comb begin
        o_valid      = 1'b0;
        o_src_port   = '0;
        o_src_mac    = '0;
        o_dst_mac    = '0;
        o_status_ren = '0;
        o_length_ren = '0;
        o_srcmac_ren = '0;
        o_dstmac_ren = '0;

        case (mac_state)
            MAC_IDLE: begin
                // Drop path: no MAC request; pop metadata this cycle
                if (arb_found && !i_valid[arb_port]) begin
                    o_status_ren[arb_port] = 1'b1;
                    o_length_ren[arb_port] = 1'b1;
                    o_srcmac_ren[arb_port] = 1'b1;
                    o_dstmac_ren[arb_port] = 1'b1;
                end
            end

            MAC_REQ: begin
                // Valid path: assert MAC learner request for one cycle
                o_valid    = 1'b1;
                o_src_port = 4'b0001 << sel_port;
                o_src_mac  = i_src_mac[sel_port];
                o_dst_mac  = i_dst_mac[sel_port];
            end

            MAC_WAIT: begin
                // Pop metadata coincident with tx start (on i_done)
                if (i_done) begin
                    o_status_ren[sel_port] = 1'b1;
                    o_length_ren[sel_port] = 1'b1;
                    o_srcmac_ren[sel_port] = 1'b1;
                    o_dstmac_ren[sel_port] = 1'b1;
                end
            end

            default: ;
        endcase
    end

    // ----------------------------------------------------------------
    // Per-port combinatorial outputs to crossbar / data FIFOs
    // ----------------------------------------------------------------
    always_comb begin
        for (int p = 0; p < 4; p++) begin
            o_datafifo_ren[p]  = busy[p];
            o_packet_valid[p]  = busy[p] && !dropping[p];
            o_dst_port[p]      = (busy[p] && !dropping[p]) ? dst_port_r[p] : 4'b0;  // Don't put trash out for dst_port for an invalid packet
            o_packet_length[p] = (busy[p] && !dropping[p]) ? length_r[p]   : 11'b0; // Don't put the length out for an invalid packet
        end
    end

endmodule
