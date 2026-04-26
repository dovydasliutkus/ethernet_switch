`timescale 1ns/1ps


// THIS SHOULD BE THE SAME AS TOP_TB

import switch_pkg::*;

module switch_top_tb;

    // ---------------------------------------------------
    // Parameters
    // ---------------------------------------------------
    localparam int PORTS  = 4;
    localparam int DATA_W = 8;
    localparam int STALL_LIMIT = 8000;

    // Clock
    logic clk = 0;
    always #5 clk = ~clk;

    // ---------------------------------------------------
    // Interface
    // ---------------------------------------------------
    switch_if vif(clk);

    mailbox #(frame)      exp_q        [PORTS]; // outgoing log, indexed by who sent
    mailbox #(frame)      egress_exp_q [PORTS]; // expected delivery, indexed by who should receive
    //mailbox #(captured_frame) act_q        [PORTS]; // what arrived, indexed by who received it


    switchcore dut (
        .clk       ( clk           ),
        .reset     ( vif.reset     ),
        .link_sync ( vif.link_sync ),
        .tx_data   ( vif.tx_data   ),
        .tx_ctrl   ( vif.tx_ctrl   ),
        .rx_data   ( vif.rx_data   ),
        .rx_ctrl   ( vif.rx_ctrl   )
    );



endmodule