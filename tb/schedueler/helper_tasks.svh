// --- test trackers ---

task automatic pass(input string msg);
    $display("  [PASS] T%0d: %s", test_num, msg);
    pass_count++;
endtask

task automatic fail(input string msg);
    $display("  [FAIL] T%0d: %s", test_num, msg);
    fail_count++;
endtask

// --- helper tasks ---

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

// returns 1 if met
task automatic wait_for(
    input int           max_cycles,
    ref logic[3:0]      bus,
    input int           idx, // which bit to check
    output bit          found
);
    int i;
    found = 0;
    for (i = 0; i < max_cycles; i++) begin
        if (bus[idx]) begin
            found = 1;
            break;
        end 
        @(posedge clk); #1;
    end 
    endtask

// Count how many cycles a signal is high over the next N cycles
task automatic count_cycles_high(
    input int           max_cycles,
    ref logic[3:0]      bus,
    input int           idx, // which bit to check
    output int          count
);
    int i;
    count = 0;

    for (i = 0; i < max_cycles; i++) begin 
        if (bus[idx]) count++;
        @(posedge clk); #1;
    end
endtask
