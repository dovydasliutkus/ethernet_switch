`timescale 1ns/1ps
// =============================================================================
// File        : tb_drr_schedueler.sv
// Description : Testbench for scheduler module
// =============================================================================
// TODO:
// ugh set up the uvm thing later
// randomized packets later too
// packet_len and input port should be variable
// TEST 10: back-to-back packets from same queue
// TEST 11: rr alternation between two active queues
// TEST 12: no spurious reads on empty FIFOs
// TEST 13: double check PORT_ID

module tb_drr_scheduler;

    // ---------------------------------------------------
    // Parameters
    // ---------------------------------------------------
    localparam int PORT_ID      = 2;
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
        .i_pkt_len       (i_pkt_len),
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
    always @(posedge clk) begin
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

    // ---------------------------------------------------
    // Helper tasks
    // ---------------------------------------------------    
    `include "helper_tasks.svh"

    // ---------------------------------------------------
    // TESTING TIME!!!!!!!!!!!!
    // ---------------------------------------------------
    `include "test_sequences.svh"

    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 0;

        // T1: Reset state: all outputs must be zero after reset
        test_num = 1;
        $display("\nT%0d: Reset state", test_num);
        run_test_1();

        // T2: Packet adressed to correct port gets accepted
        test_num = 2;
        $display("\nT%0d: Packet to correct port accepted", test_num);
        run_test_2();
        
        // T3: Packet adressed to WRONG port gets ignored
        test_num = 3;
        $display("\nT%0d: Packet to wrong port rejected", test_num);
        run_test_3();

        // T4: Packet dropped when data FIFO is full
        test_num = 4; 
        $display("\nT%0d: Packet dropped when FIFO full", test_num);
        run_test_4();

        // T5: Packet dropped when not enough space for whole packet
        test_num = 5; 
        $display("\nT%0d: Packet dropped when insufficient space", test_num);
        run_test_5();

        // T6: write stays high for entire packet duration
        test_num = 6; 
        $display("\nT%0d: buffer_wr_en held high for entire packet", test_num);
        run_test_6();

        // T7: Single queue, DRR read
        test_num = 7;
        $display("\nT%0d: DRR read fires for correct number of cycles", test_num);
        run_test_7();

        // T8: len_wr_en only fires once
        test_num = 8;
        $display("\nT%0d: len_wr_en pulses only once per packet (rising edge detection)", test_num);
        run_test_8();

        // T9: DRR fairness, two queues, small (64) vs large packets (1518)
        test_num = 9;
        $display("\nT%0d: DRR Fairness (Small vs Large)", test_num);
        run_test_9();
            
        $finish;

    end

endmodule