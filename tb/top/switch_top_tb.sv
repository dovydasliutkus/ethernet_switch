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
    bit [47:0] MAC0 = 48'h0000_0000_0001;
    bit [47:0] MAC1 = 48'h0000_0000_0002;
    bit [47:0] MAC2 = 48'h0000_0000_0003;
    bit [47:0] MAC3 = 48'h0000_0000_0004;


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
        join_none

        tc1();
        $finish();
    end

    /////////////// TEST CASES ////////////////////////


    task automatic tc1();

        // TC1: Basic forwarding/learning scenario
        // 1) Inject a frame into port 1 (src=MAC1, dst=MAC0).
        //    The switch should forward (or flood) this frame to the other ports
        //    while learning the source MAC on port 1.
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