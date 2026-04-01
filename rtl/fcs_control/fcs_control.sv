module fcs_control(
    input   logic  clk,
    input   logic  reset,   // Synchronous active-high

    // Inputs from ethernet PHY
    input   logic   [3:0]   i_rx_ctrl,
    input   logic   [31:0]  i_rx_data,

    // Signals to MAC learner
    input   logic   [0:3][3:0]  i_dst_port,
    input   logic               i_done,
    output  logic               o_valid,
    output  logic   [47:0]      o_dst_mac,
    output  logic   [47:0]      o_src_mac,

    // Signals to Cross-Bar
    output  logic   [3:0]       o_packet_valid,
    output  logic   [0:3][3:0]  o_dst_port,
    output  logic   [0:3][7:0]  o_data,
    output  logic   [0:3][10:0] o_packet_length
);


// If data_FIFO not full and rx_ctrll is high then record byte into data_FIFO and put it into CRC calculator


endmodule