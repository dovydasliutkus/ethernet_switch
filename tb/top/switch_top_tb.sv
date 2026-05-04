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
    initial begin
        frame f = new(48'h0, 48'h0, 0);

        f.test_known_packet();

        $finish;
    end

    // initial begin
    //     // Mailboxes
    //     for (int i = 0; i < PORTS; i++) begin
    //         exp_q[i] = new();
    //         act_q[i] = new();
    //     end

    //     drv = new(vif, exp_q);
    //     mon = new(vif, act_q);
    //    sb  = new(vif, exp_q, act_q);
    //     drv.reset();

    //     // REQUIRED
    //     vif.link_sync <= 4'b1111;

    //     fork
    //         mon.run();
    //         sb.run();
    //     join_none

    // TC1 START
    //     // Learn MAC1 on port 1
    //     drv.send_simple_frame(1, MAC1, MAC0);
    //     repeat (200) @(posedge clk);

    //     // Send to MAC1 from port 0
    //     drv.send_simple_frame(0, MAC0, MAC1);
    //     repeat (500) @(posedge clk);

    //     $display("TC1 DONE");
    //     $finish;
    // end

    ////////// DEBUGGING, TX SIDE IS DEAD//////////////////////
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