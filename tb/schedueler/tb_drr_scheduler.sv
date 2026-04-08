`timescale 1ns/1ps
// =============================================================================
// File        : tb_drr_schedueler.sv
// Description : Testbench for scheduler module
// =============================================================================
// TODO:
// TEST 1: er alle outputs nul efter reset
// Remove ctrl signal from Test 1:
// TEST 2: correct destination accepted
// TEST 3: wrong destination rejected (port-id in destport changed)
// TEST 4: full FIFO rejects packet
// TEST 5: insufficient space, packet stadig rejects
// TEST 6: checks accepting catches on correctly for active signal
// TEST 7: read fires for exactly pkt_len cycles
// TEST 8: -------
// TEST 9: FIFO pushes exactly twice for back-to-back packets
// TEST 10: byte fairness between 64-byte queue and 1518 byte queue
// TEST 11: back-to-back packets from same queue
// TEST 12: rr alternation between two active queues
// TEST 13: no spurious reads on empty FIFOs
// TEST 14: double check PORT_ID

module tb_drr_scheduler;

    // ---------------------------------------------------
    // Parameters
    // ---------------------------------------------------
    localparam int PORT_ID      = 0;
    localparam int MAX_PKT_SIZE = 1518;
    localparam int LEN_WIDTH    = $clog2(MAX_PKT_SIZE);
    localparam int FIFO_DEPTH   = 4096;
    localparam int OCC_WIDTH    = $clog2(FIFO_DEPTH);
 
    localparam int QUANTUM      = MAX_PKT_SIZE;
    localparam int CLK_PERIOD   = 8;    // 125 MHz

    // ---------------------------------------------------
    // DUT ports
    // ---------------------------------------------------
    logic                     clk;
    logic                     reset;

    logic [3:0]               pkt_valid;
    logic [3:0]               dst_port [3:0]; 
    logic[LEN_WIDTH-1:0]      i_pkt_len [3:0];   // byte length of packet at input i

    logic [OCC_WIDTH-1:0]     buffer_usedw [3:0];
    logic [3:0]               buffer_full;
    logic [3:0]               buffer_empty;
    logic [3:0]               buffer_wr_en;       
    logic [3:0]               buffer_rd_en;   

    logic                     o_tx_ctrl;

    // ---------------------------------------------------
    // DUT instantiation
    // ---------------------------------------------------
    drr_scheduler #(
        .PORT_ID      (PORT_ID),
        .MAX_PKT_SIZE (MAX_PKT_SIZE),
        .LEN_WIDTH    (LEN_WIDTH),
        .FIFO_DEPTH   (FIFO_DEPTH),
        .OCC_WIDTH    (OCC_WIDTH)
    ) dut (
        .i_clk           (clk),
        .i_reset         (reset),
        .i_pkt_valid     (pkt_valid),
        .i_dst_port      (dst_port),
        .i_pkt_len     (i_pkt_len),
        .i_buffer_usedw  (buffer_usedw),
        .i_buffer_full   (buffer_full),
        .i_buffer_empty  (buffer_empty),
        .o_buffer_wr_en  (buffer_wr_en),
        .o_buffer_rd_en  (buffer_rd_en)
    );

    // ---------------------------------------------------
    // Clock generation
    // ---------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------------------------------------------------
    // Buffering
    // ---------------------------------------------------
    int fifo_count [3:0];

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            buffer_usedw[i] = OCC_WIDTH'(fifo_count[i]);
            buffer_full[i] = (fifo_count[i] >= FIFO_DEPTH);
            buffer_empty[i] = (fifo_count[i] == 0);
        end
    end

    // updating fifo counts
    always_ff @(posedge clk) begin
        for (int i = 0; i < 4; i++) begin
            if (buffer_wr_en[i] && !buffer_full[i])
                fifo_count[i] <= fifo_count[i] + 1;
            if (buffer_rd_en[i] && !buffer_empty[i])
                fifo_count[i] <= fifo_count[i] - 1;
        end
    end

    // ---------------------------------------------------
    // Test trackers
    // ---------------------------------------------------
    int test_num;
    int pass_count;
    int fail_count;

    task automatic pass(input string msg);
        $display("  [PASS] T%0d: %s", test_num, msg);
        pass_count++;
    endtask

    task automatic fail(input string msg);
        $display("  [FAIL] T%0d: %s", test_num, msg);
        fail_count++;
    endtask

    // ---------------------------------------------------
    // Helper tasks
    // ---------------------------------------------------    

    task automatic do_reset();
        reset = 0;
        pkt_valid = '0;

        for (int i = 0; i < 4; i++) begin
            dst_port[i] = '0;
            i_pkt_len[i] = '0;
            fifo_count[i] = 0;
        end 

        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 1;
        @(posedge clk); #1;
    endtask

    // drive packet from input port src, destined for dst, for pkt_len cycles
    task automatic drive_packet(
        input int src,
        input int dst,
        input int pkt_len
    );
        dst_port[src] = 4'(1 << dst);
        i_pkt_len[src] = LEN_WIDTH'(pkt_len);
        pkt_valid[src] = 1'b1;
        repeat (pkt_len) @(posedge clk);
        #1;
        dst_port[src] = '0;
        i_pkt_len[src] = '0;
        pkt_valid[src] = 1'b0; 
    endtask

    task automatic wait_for(
        input int       max_cycles,
        input string    signal_name,
        ref logic       sig
    );
        int i;
        for (i = 0; i < max_cycles; i++) begin
            if (sig) break;
            @(posedge clk); #1;
        end 

        if (i == max_cycles)
            $display("  [WARN] T%0d: %s never went high in %0d cycles", test_num, signal_name, max_cycles);
    endtask

    // ---------------------------------------------------
    // TESTING TIME!!!!!!!!!!!!
    // --------------------------------------------------- 
    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 0;

        do_reset();

        // ---------------------------------------------------
        // T1: Reset state: all outputs must be zero after reset
        // --------------------------------------------------- 

        test_num = 1;
        $display("\nT%0d: Reset state", test_num);
        if (buffer_wr_en !== 4'b0000) fail("buffer_wr_en not zero after reset");
        else                           pass("buffer_wr_en zero after reset");
        if (buffer_rd_en !== 4'b0000) fail("buffer_rd_en not zero after reset");
        else                           pass("buffer_rd_en zero after reset");
    end

endmodule