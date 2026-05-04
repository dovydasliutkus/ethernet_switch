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
       
        drv.send_simple_frame(1, MAC1, MAC0);
        
        wait (mon.frame_count[0] + mon.frame_count[2] + mon.frame_count[3] >= 3);
        
        drv.send_simple_frame(0, MAC0, MAC1);
        
        wait (mon.frame_count[1] >= 1);
        
        sb.report("TC1");

    endtask


    ////////////////////////////// DEBUGGING /////////////////////////////////////////////
    // Debug TX
    always @(posedge clk) begin
        if (vif.tx_ctrl != 0) begin
            $display("[%0t] TX: ctrl=%b data=%h",
                     $time, vif.tx_ctrl, vif.tx_data);
        end
    end

    //  Debug RX
    always @(posedge clk) begin
        if (vif.rx_ctrl != 0)
            $display("[%0t] RX ACTIVE: %b data=%h", $time, vif.rx_ctrl, vif.rx_data);
    end
endmodule