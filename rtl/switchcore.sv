module switchcore (
    input  wire        clk,
    input  wire        reset,

    // // Activity indicators
    input  wire [3:0]  link_sync,   // High indicates a peer connection at the physical layer (cable plugged in)

    // Four GMII interfaces
    output wire  [31:0] tx_data,     // (7:0)=TXD0 ... (31:24)=TXD3
    output wire  [3:0]  tx_ctrl,     // (0)=TXC0 ... (3)=TXC3
    input  wire  [31:0] rx_data,     // (7:0)=RXD0 ... (31:24)=RXD3
    input  wire  [3:0]  rx_ctrl      // (0)=RXC0 ... (3)=RXC3
);

    // fcs_control <-> mac_learner wires
    wire        mac_valid;
    wire [3:0]  mac_src_port;
    wire [47:0] mac_src_mac;
    wire [47:0] mac_dst_mac;
    wire [3:0]  mac_dst_port;
    wire        mac_done;

    // fcs_control -> crossbar wires
    wire [3:0]  packet_valid;
    wire [3:0]  dst_port      [3:0];
    wire [7:0]  data          [3:0];
    wire [10:0] packet_length [3:0];
    wire [31:0] data_flat;

    // For fcs_control -> crossbar connection 
    assign data_flat = {data[3], data[2], data[1], data[0]};

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

    // crossbar_top instance
    crossbar_top u_crossbar_top (
        .i_clk       ( clk           ),
        .i_rst       ( reset         ),
        .i_data      ( data_flat     ),
        .i_pkt_valid ( packet_valid  ),
        .i_dst_port  ( dst_port      ),
        .i_pkt_len   ( packet_length ),
        .o_tx_data   ( tx_data       ),
        .o_tx_ctrl   ( tx_ctrl       )
    );

endmodule

// ----------------------------------------------------------------
// Direct connect Port0 <-> Port1
// ---------------------------------------------------------------
// module switchcore (
//     input  wire        clk,
//     input  wire        reset,

//     // Activity indicators
//     input  wire [3:0]  link_sync,   // High indicates a peer connection at the physical layer (cable plugged in)

//     // Four GMII interfaces
//     output reg  [31:0] tx_data,     // (7:0)=TXD0 ... (31:24)=TXD3
//     output reg  [3:0]  tx_ctrl,     // (0)=TXC0 ... (3)=TXC3
//     input  wire [31:0] rx_data,     // (7:0)=RXD0 ... (31:24)=RXD3
//     input  wire [3:0]  rx_ctrl      // (0)=RXC0 ... (3)=RXC3
// );

// always @(posedge clk) begin
//     if (!reset) begin
//         tx_data[7:0]   <= 8'b0;
//         tx_data[15:8]  <= 8'b0;
//         tx_ctrl[0]     <= 1'b0;
//         tx_ctrl[1]     <= 1'b0;
//     end else begin
//         // Simple forward from Port0 to Port1 and from Port1 to Port0
//         tx_data[7:0]   <= rx_data[15:8];
//         tx_data[15:8]  <= rx_data[7:0];
//         tx_ctrl[0]     <= rx_ctrl[1];
//         tx_ctrl[1]     <= rx_ctrl[0];
//     end
// end

// endmodule