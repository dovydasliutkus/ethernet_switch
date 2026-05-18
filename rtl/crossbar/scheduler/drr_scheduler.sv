// =============================================================================
// File        : drr_schedueler.sv
// Description : Scheduler module implementing Deficit Round-Robin
// =============================================================================
// 1. TODO: add a safety feature in case i_pkt_valid goes low mid transaction

module drr_scheduler #(
    parameter int PORT_ID       = 0,
    parameter int MAX_PKT_SIZE  = 1518,                 // Bytes of credit added per DRR turn
    parameter int LEN_WIDTH     = $clog2(MAX_PKT_SIZE), // Packet length field width (for max. 1518 byte packet)
    parameter int FIFO_DEPTH    = 4096,                 // data FIFO depth
    parameter int OCC_WIDTH     = $clog2(FIFO_DEPTH)    // Occupancy width from Quartus FIFO IP
)(
    input logic                      i_clk,
    input logic                      i_reset,

    // ---------------------------------------------------
    // FCS/control signals
    // ---------------------------------------------------
    input logic [3:0]                i_pkt_valid,
    input logic [3:0]                i_dst_port [3:0],
    input logic[LEN_WIDTH-1:0]       i_pkt_len [3:0],   // byte length of packet at input i

    // ---------------------------------------------------
    // buffer block signals
    // ---------------------------------------------------
    input  logic [4*OCC_WIDTH-1:0]   i_buffer_usedw,
    input  logic [3:0]               i_buffer_full,
    input  logic [3:0]               i_buffer_empty,
    output logic [3:0]               o_buffer_wr_en,       
    output logic [3:0]               o_buffer_rd_en   
);

    // ---------------------------------------------------
    // Shadow FIFO signals for packet length storage
    // Quartus IP: show-ahead mode, 11-bit wide, 64 deep, logic cells only
    // ---------------------------------------------------

    logic [3:0]             len_wr_en;
    logic [3:0]             len_rd_en;
    logic [LEN_WIDTH-1:0]   len_head [3:0];
    logic [3:0]             len_empty;
    logic [3:0]             len_full;

    genvar g;
    generate
        for (g = 0; g < 4; g++) begin : g_len_fifo
            pkt_len_fifo u_len_fifo (
                .clock  (i_clk),
                .data   (i_pkt_len[g]),
                .rdreq  (len_rd_en[g]),
                .wrreq  (len_wr_en[g]),
                .sclr   (~i_reset),
                .empty  (len_empty[g]),
                .full   (len_full[g]),
                .q      (len_head[g]),
                .usedw  ()
            );
        end
    endgenerate

    // ---------------------------------------------------
    // write enable logic
    // ---------------------------------------------------

    // rising edge detector
    logic [3:0] prev_valid;

    always_ff @(posedge i_clk) begin
        if (!i_reset) prev_valid <= '0;
        else        prev_valid <= i_pkt_valid;
    end

    logic [3:0] pkt_start;
    assign pkt_start = i_pkt_valid & ~prev_valid;  // high for first byte of each packet only

    // occupancy counter
    logic [OCC_WIDTH:0] space_left [3:0];

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            if (i_buffer_full[i])
                space_left[i] = '0;
            // else if (i_buffer_empty[i])
            //     space_left[i] = (OCC_WIDTH + 1)'(FIFO_DEPTH);
            else
                space_left[i] = (OCC_WIDTH + 1)'(FIFO_DEPTH) - i_buffer_usedw[i*OCC_WIDTH +: OCC_WIDTH];
        end
    end

    // write + shadow FIFO push
    logic [3:0] accepting;
    logic [3:0] will_accept;
    
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            will_accept[i] = i_pkt_valid[i] 
<<<<<<< HEAD
                           & i_dst_port[i] 
                        //    & (space_left[i] >= OCC_WIDTH'(i_pkt_len[i])) 
=======
                           & i_dst_port[i][PORT_ID]
                           & (space_left[i] >= OCC_WIDTH'(i_pkt_len[i])) 
>>>>>>> crossbar_fix
                           & ~i_buffer_full[i] 
                           & ~len_full[i]
                           & i_reset;
        end
    end

    // VERSION WHERE ACCEPTING CAN'T change mid transaction
    always_ff @(posedge i_clk) begin
        if (!i_reset) accepting <= '0;
        else begin
            for (int i = 0; i < 4; i++) begin
                if (pkt_start[i] & will_accept[i])   accepting[i] <= 1'b1;  // commit on first byte
                else if (!i_pkt_valid[i])             accepting[i] <= 1'b0;  // clear when packet ends
            end
        end
    end

    // PREVIOUS VERSION
    // always_ff @(posedge i_clk) begin
    //     if (!i_reset) accepting <= '0;
    //     else          accepting <= will_accept; // to make sure wr_en doesnt go low mid transaction
    // end

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            o_buffer_wr_en[i] = (pkt_start[i] & will_accept[i]) | (i_pkt_valid[i] & accepting[i]);
            len_wr_en[i]    = pkt_start[i] & will_accept[i];  // push length once on first byte
        end
    end

    // ---------------------------------------------------
    // DRR state machine
    // ---------------------------------------------------
    
    typedef enum logic [1:0] {
        S_SCAN      = 2'b00,
        S_DECIDE    = 2'b01,
        S_SERVE     = 2'b10,
        S_NEXT_PKT  = 2'b11
    } state_t;

    state_t state;

    logic [1:0]                     rr_ptr;          // which queue are we in? (0-3)
    logic [$clog2(MAX_PKT_SIZE):0]  deficit [3:0];   // how many bytes of credit does queue i have?
    logic [LEN_WIDTH-1:0]           tx_remaining;    // bytes left in current transmission
    logic [LEN_WIDTH-1:0]           current_pkt_len; // for saving length at commit time

    localparam [10:0] QUANTUM = MAX_PKT_SIZE[10:0];

    always_ff @(posedge i_clk) begin
        if (!i_reset) begin 
            state         <= S_SCAN;
            rr_ptr        <= '0;
            o_buffer_rd_en  <= '0;
            len_rd_en     <= '0;
            tx_remaining  <= '0;
            current_pkt_len <= '0;
            for (int i = 0; i < 4; i++) deficit[i] <= '0;
        end else begin      
            o_buffer_rd_en <= '0;
            len_rd_en    <= '0;

            case (state)
                // -----------------------------------------------------------
                // S_SCAN: Look for a queue with data
                // -----------------------------------------------------------
                S_SCAN: begin
                    if (len_empty[rr_ptr]) begin
                    deficit[rr_ptr] <= '0; // prevents credit hoarding
                    rr_ptr          <= rr_ptr + 2'd1; 
                    end else begin
                        deficit[rr_ptr] <= deficit[rr_ptr] + {1'b0, QUANTUM}; // add quantum once per visit 
                        state           <= S_DECIDE;        // found data!       
                    end
                end
                // -----------------------------------------------------------
                // S_DECIDE: Check if we have enough credit for the head packet
                // -----------------------------------------------------------
                S_DECIDE: begin 
                    if (deficit[rr_ptr] >= len_head[rr_ptr]) begin
                        // success! load counters and pop the Shadow FIFO
                        current_pkt_len   <= len_head[rr_ptr];
                        tx_remaining      <= len_head[rr_ptr];
                        len_rd_en[rr_ptr] <= 1'b1; // pop shadow FIFO
                        state             <= S_SERVE;
                    end else begin
                        // not enough credit, move to next port.
                        rr_ptr <= rr_ptr + 2'd1;
                        state  <= S_SCAN;
                    end
                end
                // -----------------------------------------------------------
                // S_SERVE: Transmit data until packet is done
                // -----------------------------------------------------------
                S_SERVE: begin 
                    if (tx_remaining > 0) begin
                        o_buffer_rd_en[rr_ptr] <= 1'b1;
                        tx_remaining         <= tx_remaining - 1'b1;
                        
                        // if this was the last byte...
                        if (tx_remaining == 1) begin
                            // subtract the cost from our deficit
                            deficit[rr_ptr] <= deficit[rr_ptr] - {1'b0, current_pkt_len};
                            state           <= S_NEXT_PKT;
                        end
                    end
                end
                // -----------------------------------------------------------
                // S_NEXT_PKT: The "Back-to-Back" check
                // -----------------------------------------------------------
                S_NEXT_PKT: begin 
                    // one cycle delay here allows the Shadow FIFO to update
                    if (!len_empty[rr_ptr]) begin
                        // can we afford another packet immediately?
                        state <= S_DECIDE; 
                    end else begin
                        rr_ptr <= rr_ptr + 2'd1;
                        state  <= S_SCAN;
                    end
                end
                default: state <= S_SCAN;
            endcase
        end
    end

    // // amal: debugging
    // always @(posedge i_clk) begin
    //     $display("[%0t] SCHED %0d | rr_ptr=%0d | len_empty=%b | deficit=%0d",
    //         $time, PORT_ID, rr_ptr, len_empty[rr_ptr], deficit[rr_ptr]);
    // end
    always @(posedge i_clk) begin
    // $display("cycle dst_port = %b", i_dst_port);
    end
endmodule
   