// --- The Actual Tests ---

task automatic run_test_1();
    do_reset();
    if (buffer_wr_en !== 4'b0000) fail("buffer_wr_en not zero after reset");
    else                           pass("buffer_wr_en zero after reset");
    if (buffer_rd_en !== 4'b0000) fail("buffer_rd_en not zero after reset");
    else                           pass("buffer_rd_en zero after reset");
endtask

task automatic run_test_2();
    int wr_high;
    do_reset();
    dst_port[0]  = (4'b0001 << PORT_ID);    // one-hot for port 0, from port 0
    i_pkt_len[0] = 11'd64;
    pkt_valid[0] = 1'b1;
    @(posedge clk); #1;        // pkt_start fires here
    @(posedge clk); #1;        // accepting[0] latched, wr_en should follow

    count_cycles_high(64, buffer_wr_en, 0, wr_high);
    pkt_valid[0] = 1'b0;

    if (wr_high > 0) pass($sformatf("buffer_wr_en[0] was high for %0d cycles", wr_high));
    else             fail("buffer_wr_en[0] never went high");
endtask

task automatic run_test_3();
    bit saw_wr_en;
    do_reset();

    dst_port[0]  = (4'b0001 << (PORT_ID + 1));    // one-hot for port 1, from port 0
    i_pkt_len[0] = 11'd64;
    pkt_valid[0] = 1'b1;

    wait_for(64, buffer_wr_en, 0, saw_wr_en);

    pkt_valid[0] = 1'b0;

    if (!saw_wr_en) 
        pass("buffer_wr_en[0] stayed low (correctly ignored wrong dest)");
    else            
        fail("buffer_wr_en[0] went high for a packet meant for port 1");
endtask

task automatic run_test_4();
    bit saw_wr_en;
    do_reset();
    fifo_count[0] = FIFO_DEPTH; // force fifo full flag

    dst_port[0]  = (4'b0001 << PORT_ID);
    i_pkt_len[0] = 11'd64;
    pkt_valid[0] = 1'b1;

    @(posedge clk); #1;

    wait_for(64, buffer_wr_en, 0, saw_wr_en);

    if (!saw_wr_en) 
        pass("buffer_wr_en[0] stayed low (correctly dropped packet)");
    else            
        fail("buffer_wr_en[0] went high (didn't drop packet when FIFO full)");

    pkt_valid[0] = 1'b0;
    fifo_count[0] = 0;
endtask

task automatic run_test_5();
    bit saw_wr_en;
    do_reset();
    fifo_count[0] = FIFO_DEPTH; // force fifo full flag

    dst_port[0]  = (4'b0001 << PORT_ID);
    i_pkt_len[0] = 11'd64;
    pkt_valid[0] = 1'b1;

    @(posedge clk); #1;

    wait_for(64, buffer_wr_en, 0, saw_wr_en);

    if (!saw_wr_en) 
        pass("buffer_wr_en[0] stayed low (correctly dropped packet)");
    else            
        fail("buffer_wr_en[0] went high (didn't drop packet when FIFO full)");

    pkt_valid[0] = 1'b0;
    fifo_count[0] = 0;
endtask

task automatic run_test_6();
    int wr_count;
    int pkt_len;
    pkt_len = 200;
    do_reset();
    dst_port[0]  = (4'b0001 << PORT_ID);
    i_pkt_len[0] = LEN_WIDTH'(pkt_len);
    pkt_valid[0] = 1'b1;
    @(posedge clk); #1;    // pkt_start
    @(posedge clk); #1;    // accepting latched
    count_cycles_high(pkt_len - 1, buffer_wr_en, 0, wr_count);
    pkt_valid[0] = 1'b0;
    @(posedge clk); #1;
    if (buffer_wr_en[0] !== 1'b0) fail("buffer_wr_en[0] still high after packet ended");

    if (wr_count == pkt_len - 1)
        pass($sformatf("buffer_wr_en[0] high for correct duration (%0d cycles)", wr_count));
    else
        fail($sformatf("buffer_wr_en[0] high for %0d cycles, expected %0d", wr_count, pkt_len - 1));

endtask

task automatic run_test_7();   
    int rd_count;
    int pkt_len;
    bit saw_rd_en;
    pkt_len = 100;
    do_reset();

    // Drive the packet realistically in the background (holds valid high for 100 cycles)
    fork 
        drive_packet(0, PORT_ID, pkt_len);
    join_none

    // while the packet is arriving, wait for the DRR to wake up and start reading
    wait_for(20, buffer_rd_en, 0, saw_rd_en);

    // count how long read_en stays high
    count_cycles_high(pkt_len + 10, buffer_rd_en, 0, rd_count);

    if (rd_count == pkt_len)
        pass($sformatf("buffer_rd_en[0] high for exactly %0d cycles", rd_count));
    else
        fail($sformatf("buffer_rd_en[0] high for %0d cycles, expected %0d", rd_count, pkt_len));

endtask
task automatic run_test_8();
    int pkt_len = 64;
    int rd_pulses = 0;
    logic prev_rd = 0;
    do_reset();

    // 1. start driving packets
    fork
        begin
            drive_packet(0, PORT_ID, pkt_len);
            repeat(5) @(posedge clk); // Give the scheduler a tiny breathing room
            drive_packet(0, PORT_ID, pkt_len);
        end
    join_none

    // 2. Monitor for EXACTLY two start-of-packet pulses
    repeat (pkt_len * 3) begin
        @(posedge clk);
        // Detect Rising Edge: high now, but was low last cycle
        if (buffer_rd_en[0] && !prev_rd) begin
            rd_pulses++;
        end
        prev_rd = buffer_rd_en[0]; 
    end

    if (rd_pulses == 2)
        pass("Detected exactly two separate read bursts (pulses)");
    else
        fail($sformatf("Detected %0d read pulses, expected 2", rd_pulses));
endtask

task automatic run_test_9();
    int small_len = 64;
    int large_len = 500; // 500 bcs faster (im being lazy)
    int rd0_count = 0, rd1_count = 0;
    do_reset();

    // 1. Drive pakcets in the background
    fork
        repeat (10) drive_packet(0, PORT_ID, small_len);
        repeat (3)  drive_packet(1, PORT_ID, large_len);
    join_none 

    // 2. While they drive, we measure 
    repeat (2000) begin
        @(posedge clk);
        if (buffer_rd_en[0]) rd0_count++;
        if (buffer_rd_en[1]) rd1_count++;
    end

    // 3. Compare
    $display("  Read counts - Q0: %0d, Q1: %0d", rd0_count, rd1_count);
    if (rd0_count > 0 && rd1_count > 0) pass("Both queues served");
    else fail("One or both queues starved");
endtask