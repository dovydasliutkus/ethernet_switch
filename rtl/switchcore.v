module switchcore (
    input  logic        clk,
    input  logic        reset,

    // // Activity indicators
    input  wire [3:0]  link_sync,   // High indicates a peer connection at the physical layer (cable plugged in)

    // Four GMII interfaces
    output logic  [31:0] tx_data,     // (7:0)=TXD0 ... (31:24)=TXD3
    output logic  [3:0]  tx_ctrl,     // (0)=TXC0 ... (3)=TXC3
    input  logic [31:0] rx_data,     // (7:0)=RXD0 ... (31:24)=RXD3
    input  logic [3:0]  rx_ctrl      // (0)=RXC0 ... (3)=RXC3
);

    // fcs_control <-> mac_learner wires
    logic        mac_valid;
    logic [3:0]  mac_src_port;
    logic [47:0] mac_src_mac;
    logic [47:0] mac_dst_mac;
    logic [3:0]  mac_dst_port;
    logic        mac_done;

    // fcs_control -> crossbar wires
    logic [3:0]  packet_valid;
    logic [3:0]  dst_port      [3:0];
    logic [7:0]  data          [3:0];
    logic [10:0] packet_length [3:0];

    // fcs_control instance
    fcs_control u_fcs_control (
        .i_clk          ( clk              ),
        .i_reset        ( reset            ),
        // PHY receive
        .i_rx_ctrl      ( rx_ctrl          ),
        .i_rx_data      ( rx_data          ),
        // MAC learner
        .i_dst_port     ( mac_dst_port   ),
        .i_done         ( mac_done       ),
        .o_valid        ( mac_valid      ),
        .o_src_port     ( mac_src_port   ),
        .o_dst_mac      ( mac_dst_mac    ),
        .o_src_mac      ( mac_src_mac    ),
        // Crossbar
        .o_packet_valid ( packet_valid   ),
        .o_dst_port     ( dst_port       ),
        .o_data         ( data           ),
        .o_packet_length( packet_length  )
    );

    // mac_learner instance
    mac_learner u_mac_learner (
        .clk      ( clk              ),
        .reset    ( reset            ),
        .valid    ( mac_valid      ),
        .src_port ( mac_src_port   ),
        .src_mac  ( mac_src_mac    ),
        .dst_mac  ( mac_dst_mac    ),
        .dst_port ( mac_dst_port   ),
        .done     ( mac_done       )
    );

endmodule
