`timescale 1ns/1ps

import switch_pkg::*;

module switch_top_tb;

    localparam int PORTS  = 4;
    localparam int DATA_W = 8;

    // Clock
    logic clk = 0;
    always #5 clk = ~clk;

    // Interface
    switch_if vif(clk);

    // MACs (FIXED LOCATION)
    bit [47:0] MAC0 = 48'h0000_0000_0000;
    bit [47:0] MAC1 = 48'h0000_0000_0001;
    bit [47:0] MAC2 = 48'h0000_0000_0002;
    bit [47:0] MAC3 = 48'h0000_0000_0003;
    bit [47:0] macs [4] = '{MAC0, MAC1, MAC2, MAC3};



    // Mailboxes
    mailbox #(frame) exp_q [PORTS];
    mailbox #(frame) act_q [PORTS];

    // Components
    switch_driver #(PORTS, DATA_W) drv;
    tx_monitor    #(PORTS, DATA_W) mon;
    scoreboard    #(PORTS)         sb;

    // DUT
    switchcore dut (
        .clk       ( clk           ),
        .reset     ( vif.reset     ),
        .link_sync ( vif.link_sync ),
        .tx_data   ( vif.tx_data   ),
        .tx_ctrl   ( vif.tx_ctrl   ),
        .rx_data   ( vif.rx_data   ),
        .rx_ctrl   ( vif.rx_ctrl   )
    );

    // TEST
    // DEBUGGING CRC
    // initial begin
    //     frame f = new(48'h0, 48'h0, 0);

    //     f.test_known_packet();

    //     $finish;
    // end

    /////////////// Helper taks ////////////////////////
    // wrapper for sending dynamically sized frames
    task automatic send_dynamic_frame(
        int src, 
        bit [47:0] src_mac, 
        bit [47:0] dst_mac, 
        int len
    );
        frame f = new(src_mac, dst_mac, src);
        f.build(len);
        drv.send_frame(f);
    endtask

    // Helper to reset monitor counts between tests
    task automatic clear_monitor_counts();
        for(int i=0; i<PORTS; i++) mon.frame_count[i] = 0;
    endtask

    task automatic send_corrupted_dynamic_frame(
        int src,
        bit [47:0] src_mac,
        bit [47:0] dst_mac,
        int len
    );
        frame f = new(src_mac, dst_mac, src);
        f.build(len);
        drv.send_corrupted_frame(f); // skips exp_q and mac_table
    endtask

    /////////////// Main execution ////////////////////////

    initial begin
        // Mailboxes
        for (int i = 0; i < PORTS; i++) begin
            exp_q[i] = new();
            act_q[i] = new();
        end

        drv = new(vif, exp_q);
        mon = new(vif, act_q);
        sb  = new(vif, exp_q, act_q);
        drv.reset();

        // REQUIRED
        vif.link_sync <= 4'b1111;

        fork
            mon.run();
            sb.run();
            drv.run();
        join_none

        // Run the tests
        tc1();
        tc2();
        tc3();
        tc4();
        tc5();
        tc6();
        tc7();
        tc8();
        tc9();
        tc10();
        sb.suite_report();
        $finish();
    end

    /////////////// TEST CASES ////////////////////////

    // TC1: Single packet
    task automatic tc1();
        sb.start_tc("TC1");

        // 1) Inject a frame into port 1 (src=MAC1, dst=MAC0).
        //    The switch should forward (or flood) this frame to the other ports
        //    while learning the source MAC on port 1.
        clear_monitor_counts();
        drv.send_simple_frame(1, MAC1, MAC0);

        // 2) Wait until the monitor has observed the forwarded frames
        //    on ports 0, 2 and 3 (3 frames total).
        wait (mon.frame_count[0] + mon.frame_count[2] + mon.frame_count[3] >= 3);

        // 3) Send a frame from port 0 (src=MAC0, dst=MAC1).
        //    Since MAC1 was learned on port 1, the frame should be
        //    delivered to port 1 only.
        drv.send_simple_frame(0, MAC0, MAC1);

        // 4) Wait until the monitor sees the frame on port 1.
        wait (mon.frame_count[1] >= 1);

        for (int i = 0; i< 20;i++) begin
            drv.send_simple_frame(0, MAC0, MAC1); 
            wait (mon.frame_count[1] >= i + 2);
        end
        // 5) Report the test case result to the scoreboard.
        sb.report("TC1");

    endtask

    // TC2: Randomized Independent Traffic
    task automatic tc2();
        localparam int NUM_FRAMES = 10;
        int payload_len, src_port, dst_port;

        sb.start_tc("TC2");
        clear_monitor_counts();

        // Learning phase
        for (int p = 0; p < PORTS; p++) begin
            drv.send_simple_frame(p, macs[p], macs[(p+1)%PORTS]);
        end
        repeat(200) @(vif.cb);
        clear_monitor_counts();

        // Randomized traffic with variable payload sizes
        for (int n = 0; n < NUM_FRAMES * PORTS; n++) begin
            src_port = $urandom_range(0, PORTS-1);
            dst_port = (src_port + 1) % PORTS;
            payload_len = $urandom_range(46, 1500); 
            send_dynamic_frame(src_port, macs[src_port], macs[dst_port], payload_len);
        end

        wait (mon.frame_count[0] + mon.frame_count[1] + 
              mon.frame_count[2] + mon.frame_count[3] >= NUM_FRAMES * PORTS);
        
        sb.report("TC2");

    endtask

    // TC3: Multiple inputs, same output
    task automatic tc3();
        localparam int NUM_FRAMES = 10;
        int expected_total = NUM_FRAMES * 3; // 3 ports sending to 1

        sb.start_tc("TC3");
        clear_monitor_counts();

        // Ports 1, 2, and 3 all send to Port 0
        for (int p = 1; p < PORTS; p++) begin
            for (int n = 0; n < NUM_FRAMES; n++) begin
                send_dynamic_frame(p, macs[p], MAC0, $urandom_range(46, 1500));
            end
        end

        wait (mon.frame_count[0] >= expected_total);
        sb.report("TC3");
    endtask

    // TC4: Variable packet sizes across independent ports
    task automatic tc4();
        int sizes[$] = '{46, 256, 512, 1000, 1500};
        int total = sizes.size() * PORTS;

        sb.start_tc("TC4");
        clear_monitor_counts();
        
        foreach (sizes[k]) begin
            for (int p = 0; p < PORTS; p++) begin
                send_dynamic_frame(p, macs[p], macs[(p+1)%PORTS], sizes[k]);
            end
        end

        wait (mon.frame_count[0] + mon.frame_count[1] + 
              mon.frame_count[2] + mon.frame_count[3] >= total);
        sb.report("TC4");
    endtask

    // TC5: Output congestion with MAX size frames
    task automatic tc5();
        localparam int NUM_FRAMES = 8;
        int total = NUM_FRAMES * 3;

        sb.start_tc("TC5");
        clear_monitor_counts();

        for (int n = 0; n < NUM_FRAMES; n++) begin
            for (int p = 1; p < PORTS; p++) begin
                // Blast port 0 with 1500 byte payloads
                send_dynamic_frame(p, macs[p], MAC0, 1500); 
            end
        end

        wait (mon.frame_count[0] >= total);
        sb.report("TC5");

    endtask

    // TC6: Equal packet sizes to stress round-robin
    task automatic tc6();
        localparam int NUM_FRAMES = 10;
        int total = NUM_FRAMES * PORTS;

        sb.start_tc("TC6");
        clear_monitor_counts();

        for (int n = 0; n < NUM_FRAMES; n++) begin
            for (int p = 0; p < PORTS; p++) begin
                send_dynamic_frame(p, macs[p], macs[(p+2)%PORTS], 256);
            end
        end

        wait (mon.frame_count[0] + mon.frame_count[1] + 
              mon.frame_count[2] + mon.frame_count[3] >= total);
        sb.report("TC6");
    endtask

    // TC7: Highly mixed packet sizes
    task automatic tc7();
        localparam int NUM_FRAMES = 10;
        int payload_len, src_port;
        int total = NUM_FRAMES * PORTS;

        sb.start_tc("TC7");
        clear_monitor_counts();

        for (int n = 0; n < total; n++) begin
            src_port = $urandom_range(0, PORTS-1);
            case ($urandom_range(0, 2))
                0: payload_len = $urandom_range(46,  500);  // small
                1: payload_len = $urandom_range(500, 1000);  // medium
                2: payload_len = $urandom_range(1000, 1500); // large
            endcase
            send_dynamic_frame(src_port, macs[src_port], macs[(src_port+1)%PORTS], payload_len);
        end

        wait (mon.frame_count[0] + mon.frame_count[1] + 
              mon.frame_count[2] + mon.frame_count[3] >= total);
        sb.report("TC7");
    endtask

    // TC8: Starvation / Deficit Accumulation
    task automatic tc8();
        localparam int NUM_ROUNDS = 5;
        int total_expected = 0;

        sb.start_tc("TC8");
        clear_monitor_counts();

        for (int r = 0; r < NUM_ROUNDS; r++) begin
            // Port 1 sends ONE large frame to Port 0
            send_dynamic_frame(1, MAC1, MAC0, 1500);
            total_expected++;

            // Ports 2 and 3 send MANY small frames to Port 0
            for (int p = 2; p < PORTS; p++) begin
                for (int s = 0; s < 5; s++) begin
                    send_dynamic_frame(p, macs[p], MAC0, 46);
                    total_expected++;
                end
            end
        end

        wait (mon.frame_count[0] >= total_expected);
        sb.report("TC8");
    endtask

    // TC9: Error Injection
    task automatic tc9();
        localparam int NUM_VALID   = 15;
        localparam int NUM_CORRUPT = 10;
        int src_p;
        int valid_sent = 0;
        int corrupt_sent = 0;
        int total_observed = 0;
        bit [47:0] UNKNOWN_MAC = 48'hDE_AD_BE_EF_00_01;


        sb.start_tc("TC9");
        clear_monitor_counts();

        for (int i = 0; i < (NUM_VALID + NUM_CORRUPT); i++) begin
            src_p = $urandom_range(1, 3);

            if (i % 2 == 0 && corrupt_sent < NUM_CORRUPT) begin
                // Use a brand new MAC for the corrupted frame
                send_corrupted_dynamic_frame(src_p, UNKNOWN_MAC, MAC0, 64);
                corrupt_sent++;
            end else begin
                send_dynamic_frame(src_p, macs[src_p], MAC0, $urandom_range(64, 500));
                valid_sent++;
            end
        end

        wait(mon.frame_count[0] >= valid_sent);
        repeat(500) @(vif.cb); 

        // all monitor count should EQUAL exactly valid_sent.
        foreach (mon.frame_count[p]) total_observed += mon.frame_count[p];

        if (total_observed > valid_sent) begin
            $error("[TC9] FAIL: Leakage detected! %0d frames appeared that shouldn't exist.", 
                    total_observed - valid_sent);
            sb.error_count++;
        end

        // Send a valid frame to the MAC used in the corrupted packets.
        // If the switch is smart, it should FLOOD this (count > 1) because it never learned UNKNOWN_MAC.
        clear_monitor_counts();
        drv.send_simple_frame(0, MAC0, UNKNOWN_MAC); 
        
        repeat(200) @(vif.cb);
        
        // If it flooded, it should appear on ports 1, 2, and 3.
        if (mon.frame_count[1] > 0 && mon.frame_count[2] > 0) begin
            //$display("[TC9] PASS: Switch correctly ignored Source MAC of corrupted frames.");
        end else begin
            $error("[TC9] FAIL: Switch learned a MAC from a corrupted frame! Security risk.");
            sb.error_count++;
        end

        sb.report("TC9");
    endtask

    // TC10: Real contention (concurrent)
    task automatic tc10();
        // 3 senders blasting Port 0, 1 sender to Port 1 
        localparam int BURST_SIZE = 3;
        // P1->P0 x5, P2->P0 x5, P3->P0 x5, P0->P1 x5
        localparam int TOTAL = BURST_SIZE * 4;
        int payload_len;

        sb.start_tc("TC10");
        clear_monitor_counts();

        // Three ports send on Port 0 simultaneously: the stress.
        // Port 0 concurrently sends to Port 1 so all 4 input pins are active.
        for (int n = 0; n < BURST_SIZE; n++) begin
            frame f0, f1, f2, f3;
            payload_len = $urandom_range(46, 1501); 

            f0 = new(MAC0, MAC1, 0); f0.build(1499); drv.queue_frame(f0); // P0 -> P1
            f1 = new(MAC1, MAC0, 1); f1.build(1499); drv.queue_frame(f1); // P1 -> P0
            f2 = new(MAC2, MAC0, 2); f2.build(1499); drv.queue_frame(f2); // P2 -> P0
            f3 = new(MAC3, MAC0, 3); f3.build(1499); drv.queue_frame(f3); // P3 -> P0
        end


        drv.wait_all_done();

        // P0 receives 3*BURST_SIZE = 15 frames, P1 receives 1*BURST_SIZE = 5 frames
        // wait(mon.frame_count[0] >= BURST_SIZE * 3 &&
        //     mon.frame_count[1] >= BURST_SIZE * 1);

        sb.report("TC10");
    endtask
    
    ////////////////////////////// DEBUGGING /////////////////////////////////////////////
    // // Debug TX
    // always @(posedge clk) begin
    //     if (vif.tx_ctrl != 0) begin
    //         $display("[%0t] TX: ctrl=%b data=%h",
    //                  $time, vif.tx_ctrl, vif.tx_data);
    //     end
    // end

    // //  Debug RX
    // always @(posedge clk) begin
    //     if (vif.rx_ctrl != 0)
    //         $display("[%0t] RX ACTIVE: %b data=%h", $time, vif.rx_ctrl, vif.rx_data);
    // end

//////////////////////////////////////////////////////
// FIFO FULL ASSERTIONS
//////////////////////////////////////////////////////

// Data FIFO full should NEVER assert
always @(posedge clk) begin

    if (dut.u_fcs_control.w_datafifo_full != 4'b0000) begin
        $error("[%0t] ERROR: w_datafifo_full asserted = %b",
               $time,
               dut.u_fcs_control.w_datafifo_full);
    end

end


// Per-port CRC calculator FIFO checks
generate
    for (genvar p = 0; p < PORTS; p++) begin : fifo_asserts

        always @(posedge clk) begin

            if (dut.u_fcs_control.gen_crc[p]
                    .u_crc_calculator.length_fifo_full) begin

                $error("[%0t] ERROR: PORT %0d length_fifo_full asserted",
                       $time, p);
            end

            if (dut.u_fcs_control.gen_crc[p]
                    .u_crc_calculator.status_fifo_full) begin

                $error("[%0t] ERROR: PORT %0d status_fifo_full asserted",
                       $time, p);
            end

            if (dut.u_fcs_control.gen_crc[p]
                    .u_crc_calculator.dstmac_fifo_full) begin

                $error("[%0t] ERROR: PORT %0d dstmac_fifo_full asserted",
                       $time, p);
            end

            if (dut.u_fcs_control.gen_crc[p]
                    .u_crc_calculator.srcmac_fifo_full) begin

                $error("[%0t] ERROR: PORT %0d srcmac_fifo_full asserted",
                       $time, p);
            end

        end

    end
endgenerate

//////////////////////////////////////////////////////
// FIFO / BUFFER ASSERTIONS
//////////////////////////////////////////////////////

// --------------------------------------------------
// FCS CONTROL FIFO ASSERTIONS
// These FIFOs should NEVER become full
// --------------------------------------------------

always @(posedge clk) begin

    if (dut.u_fcs_control.w_datafifo_full != 4'b0000) begin
        $error("[%0t] ERROR: w_datafifo_full asserted = %b",
               $time,
               dut.u_fcs_control.w_datafifo_full);
    end

end


generate
    for (genvar p = 0; p < PORTS; p++) begin : g_fcs_fifo_asserts

        always @(posedge clk) begin

            if (dut.u_fcs_control.gen_crc[p]
                    .u_crc_calculator.length_fifo_full) begin

                $error("[%0t] ERROR: PORT %0d length_fifo_full asserted",
                       $time, p);
            end

            if (dut.u_fcs_control.gen_crc[p]
                    .u_crc_calculator.status_fifo_full) begin

                $error("[%0t] ERROR: PORT %0d status_fifo_full asserted",
                       $time, p);
            end

            if (dut.u_fcs_control.gen_crc[p]
                    .u_crc_calculator.dstmac_fifo_full) begin

                $error("[%0t] ERROR: PORT %0d dstmac_fifo_full asserted",
                       $time, p);
            end

            if (dut.u_fcs_control.gen_crc[p]
                    .u_crc_calculator.srcmac_fifo_full) begin

                $error("[%0t] ERROR: PORT %0d srcmac_fifo_full asserted",
                       $time, p);
            end

        end

    end
endgenerate


// --------------------------------------------------
// VOQ BUFFER ASSERTIONS
// --------------------------------------------------

generate
    for (genvar i = 0; i < PORTS; i++) begin : g_voq_row

        for (genvar j = 0; j < PORTS; j++) begin : g_voq_col

            always @(posedge clk) begin

                // --------------------------------------
                // FIFO FULL
                // --------------------------------------

                if (dut.u_crossbar_top
                        .u_voq_buffer_cixb2
                        .fifo_full[i][j]) begin

                    $error("[%0t] ERROR: VOQ FIFO FULL row=%0d col=%0d",
                           $time, i, j);
                    #5000;
                    $stop;
                end


                // --------------------------------------
                // WRITE WHILE FULL
                // --------------------------------------

                if (dut.u_crossbar_top
                        .u_voq_buffer_cixb2
                        .fifo_wen[i][j]

                    &&

                    dut.u_crossbar_top
                        .u_voq_buffer_cixb2
                        .fifo_full[i][j]) begin

                    $error("[%0t] ERROR: WRITE TO FULL FIFO row=%0d col=%0d",
                           $time, i, j);

                end


                // --------------------------------------
                // READ WHILE EMPTY
                // --------------------------------------

                if (dut.u_crossbar_top
                        .u_voq_buffer_cixb2
                        .fifo_ren[i][j]

                    &&

                    dut.u_crossbar_top
                        .u_voq_buffer_cixb2
                        .fifo_empty[i][j]) begin

                    $error("[%0t] ERROR: READ FROM EMPTY FIFO row=%0d col=%0d",
                           $time, i, j);

                end


                // --------------------------------------
                // HIGH OCCUPANCY WARNING
                // --------------------------------------

                if (dut.u_crossbar_top
                        .u_voq_buffer_cixb2
                        .fifo_usedw[i][j] > (4096 - 32)) begin

                    $warning("[%0t] WARNING: FIFO NEAR FULL row=%0d col=%0d used=%0d",
                             $time,
                             i,
                             j,
                             dut.u_crossbar_top
                                 .u_voq_buffer_cixb2
                                 .fifo_usedw[i][j]);

                end

            end

        end

    end
endgenerate


// --------------------------------------------------
// DRR SHADOW LENGTH FIFO ASSERTIONS
// These should NEVER become full
// --------------------------------------------------

generate
    for (genvar s = 0; s < PORTS; s++) begin : g_sched_asserts

        always @(posedge clk) begin

            if (dut.u_crossbar_top.gen_sched[s]
                    .u_drr_scheduler.len_full != 4'b0000) begin

                $error("[%0t] ERROR: Scheduler %0d len_full=%b",
                       $time,
                       s,
                       dut.u_crossbar_top.gen_sched[s]
                           .u_drr_scheduler.len_full);

            end

        end

    end
endgenerate

endmodule
