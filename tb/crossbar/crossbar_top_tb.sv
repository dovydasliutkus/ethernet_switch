`timescale 1ns/1ps

import crossbar_pkg::*;

module crossbar_top_tb;

    parameter DATA_W = 8;
    parameter PORTS  = 4;
    parameter MAX_PKT_SIZE = 1518;
    parameter LEN_WIDTH = $clog2(MAX_PKT_SIZE);

    logic clk = 0;
    always #5 clk = ~clk;

    crossbar_if #(DATA_W, PORTS, LEN_WIDTH) vif(clk);

    // queues
    mailbox #(packet) exp_q[PORTS];
    mailbox #(packet) act_q[PORTS];
    mailbox #(int)    len_q[PORTS];

    crossbar_driver #(DATA_W,PORTS,LEN_WIDTH) drv;
    tx_monitor      #(DATA_W,PORTS,LEN_WIDTH) mon;

    // DUT
    crossbar_top dut (
        .i_clk(clk),
        .i_rst(vif.rst),
        .i_data(vif.data),
        .i_pkt_valid(vif.pkt_valid),
        .i_dst_port(vif.dst_port),
        .i_pkt_len(vif.pkt_len),
        .o_tx_data(vif.tx_data),
        .o_tx_ctrl(vif.tx_ctrl)
    );

    // SCOREBOARD 
    task automatic run_scoreboard();

        int pass = 0;
        int fail = 0;

        packet exp, act;

        for (int p = 0; p < PORTS; p++) begin

            while (exp_q[p].try_get(exp)) begin

                if (!act_q[p].try_get(act)) begin
                    $display("PORT %0d: MISSING PACKET", p);
                    fail++;
                    continue;
                end

                if (exp.len != act.len) begin
                    $display("PORT %0d: LEN MISMATCH exp=%0d act=%0d",
                            p, exp.len, act.len);
                    fail++;
                end else begin
                    pass++;
                end
            end
        end

        $display("\n========== SCOREBOARD ==========");
        $display("Packets PASS = %0d", pass);
        $display("Packets FAIL = %0d", fail);
        $display("================================\n");

    endtask


    // DEBUG PRINT  (todo: needs beautifying)
    task automatic print_cycle();
        $write("[%0t] ", $time);

        for (int p = 0; p < PORTS; p++) begin
            if (vif.tx_ctrl[p])
                $write("P%0d: 0x%h ", p, vif.tx_data[p*DATA_W +: DATA_W]);
            else
                $write("P%0d: -- ", p);
        end

        $write("\n");
    endtask


    //////////////////// TEST /////////////////////////
    initial begin
        // init mailboxes
        foreach (exp_q[i]) exp_q[i] = new();
        foreach (act_q[i]) act_q[i] = new();
        foreach (len_q[i]) len_q[i] = new();

        drv = new(vif, exp_q, len_q);
        mon = new(vif, act_q, len_q);

        fork
            mon.run();
        join_none

        drv.reset();

        // TODO: insert all tests
        test_small_single_cross_port_xfer();
        test_small_parallel_cross_port_xfer();
        test_large_parallel_cross_port_xfer();

        test_small_contention_same_output();
        test_large_contention_same_output();

        run_scoreboard();

        $finish;
    end


    // debug viewer
    initial begin
        forever begin
            @(vif.cb);
            print_cycle();
        end
    end

    ////////////////////////////// TEST TASKS //////////////////////////////


    /////// NO CONTENTION BETWEEN OUTPUT PORTS, JUST BASIC FUNCTIONALITY ///////
    // passes
    task automatic test_small_single_cross_port_xfer();
        drv.send_simple_packet(0, 1); // len is fixed to 8
        wait_for_completion(1);
    endtask

    // passes
    task automatic test_small_parallel_cross_port_xfer();
        fork
            drv.send_simple_packet(0, 1); // len is fixed to 8
            drv.send_simple_packet(1, 2);
            drv.send_simple_packet(2, 3);
            drv.send_simple_packet(3, 0);
        join

        wait_for_completion(4);
    endtask 


    task automatic test_large_parallel_cross_port_xfer();
        int rand_dst_port =$urandom_range(0, PORTS-1);
        int len = 1518;  // TODO: hæv til 1518 og test overflwo 
        fork
            drv.send_packet(0, rand_dst_port, len);
            drv.send_packet(1, rand_dst_port, len);
            drv.send_packet(2, rand_dst_port, len);
            drv.send_packet(3, rand_dst_port, len);
        join

        wait_for_completion(4);

    endtask


    ///////// CONTENTION TESTS (OUTPUT PORTS COMPETE FOR SAME DESTINATION) ////////
    task automatic test_small_contention_same_output();

        fork
            drv.send_simple_packet(0, 1);
            drv.send_simple_packet(1, 1);
            drv.send_simple_packet(2, 1);
            drv.send_simple_packet(3, 1);
        join

        wait_for_completion(4);
    endtask

    task automatic test_large_contention_same_output();
        int rand_dst_port =$urandom_range(0, PORTS-1);
        int len = 1518;  // TODO: hæv til 1518 og test overflwo 
        fork
            drv.send_packet(0, rand_dst_port, len);
            drv.send_packet(1, rand_dst_port, len);
            drv.send_packet(2, rand_dst_port, len);
            drv.send_packet(3, rand_dst_port, len);
        join

        wait_for_completion(4);
    endtask













    //////// WAIT TASK ///////////
    task automatic wait_for_completion(int expected);

        int received;
        int start_count;
        int last_received;
        int idle_cycles;

        // capture starting point (important for multiple tests)
        start_count = 0;
        for (int p = 0; p < PORTS; p++)
            start_count += act_q[p].num();

        last_received = start_count;
        idle_cycles   = 0;

        while (1) begin
            @(vif.cb);

            // count total packets so far
            received = 0;
            for (int p = 0; p < PORTS; p++)
                received += act_q[p].num();

            // check completion (relative to this test's starting point)
            if ((received - start_count) >= expected)
                break;

            // stall detection
            if (received == last_received)
                idle_cycles++;
            else
                idle_cycles = 0;

            last_received = received;

            if (idle_cycles > 2000) begin
                $error("Stalled: no packets arriving");
                break;
            end
        end

        $display("[%0t] Completed: %0d packets",$time, received - start_count);

    endtask


endmodule