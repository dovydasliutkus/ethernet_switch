module fcs_control(
    input   logic  i_clk,
    input   logic  i_reset,   // Synchronous active-high

    // Inputs from ethernet PHY
    input   logic [3:0]   i_rx_ctrl,
    input   logic [31:0]  i_rx_data,

    // Signals to MAC learner
    input   logic [3:0]  i_dst_port         [3:0],
    input   logic        i_done,
    output  logic        o_valid,
    output  logic [47:0] o_dst_mac,
    output  logic [47:0] o_src_mac,

    // Signals to Cross-Bar
    output  logic [3:0]  o_packet_valid,
    output  logic [3:0]  o_dst_port         [3:0],
    output  logic [7:0]  o_data             [3:0],
    output  logic [10:0] o_packet_length    [3:0]
);


    // ----------------------------------------------------------------
    // Internal wires
    // ----------------------------------------------------------------
    logic [47:0] w_src_mac       [3:0];
    logic [47:0] w_dst_mac       [3:0];
    logic [10:0] w_packet_length [3:0];
    logic [3:0]  w_valid;
    logic [3:0]  w_status_empty;

    logic [3:0]  w_status_ren;
    logic [3:0]  w_length_ren;
    logic [3:0]  w_srcmac_ren;
    logic [3:0]  w_dstmac_ren;
    logic [3:0]  w_datafifo_ren;    // -> per-port data FIFOs (TODO)

    // ----------------------------------------------------------------
    // CRC calculators — one per ingress port
    // ----------------------------------------------------------------
    genvar p;
    generate
        for (p = 0; p < 4; p++) begin : gen_crc
            crc_calculator u_crc (
                .clk             ( i_clk                ),
                .reset           ( i_reset              ),
                .i_rx_ctrl       ( i_rx_ctrl[p]         ),
                .i_data          ( i_rx_data[p*8 +: 8]  ),
                .src_mac         ( w_src_mac[p]         ),
                .dst_mac         ( w_dst_mac[p]         ),
                .o_packet_length ( w_packet_length[p]   ),
                .o_valid         ( w_valid[p]           ),
                .i_status_ren    ( w_status_ren[p]      ),
                .i_length_ren    ( w_length_ren[p]      ),
                .i_srcmac_ren    ( w_srcmac_ren[p]      ),
                .i_dstmac_ren    ( w_dstmac_ren[p]      ),
                .o_status_empty  ( w_status_empty[p]    ),
                .o_length_empty  (                      ),  // TODO: connect if output_control needs it
                .o_srcmac_empty  (                      ),
                .o_dstmac_empty  (                      )
            );
        end
    endgenerate

    // ----------------------------------------------------------------
    // Output control
    // ----------------------------------------------------------------
    output_control u_output_ctrl (
        .i_clk           ( i_clk           ),
        .i_reset         ( i_reset         ),
        // Metadata FIFO heads
        .i_src_mac       ( w_src_mac       ),
        .i_dst_mac       ( w_dst_mac       ),
        .i_packet_length ( w_packet_length ),
        .i_valid         ( w_valid         ),
        .i_status_empty  ( w_status_empty  ),
        // Metadata FIFO pop pulses
        .o_status_ren    ( w_status_ren    ),
        .o_length_ren    ( w_length_ren    ),
        .o_srcmac_ren    ( w_srcmac_ren    ),
        .o_dstmac_ren    ( w_dstmac_ren    ),
        // Data FIFO drain
        .o_datafifo_ren  ( w_datafifo_ren  ),
        // MAC learner
        .o_valid         ( o_valid         ),
        .o_src_mac       ( o_src_mac       ),
        .o_dst_mac       ( o_dst_mac       ),
        .i_done          ( i_done          ),
        .i_dst_port      ( i_dst_port[0]   ),  // NOTE: fcs_control declares i_dst_port as [3:0][3:0]; only [0] used — consider changing port to plain logic [3:0]
        // Crossbar
        .o_packet_valid  ( o_packet_valid  ),
        .o_dst_port      ( o_dst_port      ),
        .o_packet_length ( o_packet_length )
    );

endmodule