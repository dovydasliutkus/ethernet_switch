module fcs_control(
    input   logic  i_clk,
    input   logic  i_reset,   // Synchronous active-high

    // Inputs from ethernet PHY
    input   logic [3:0]   i_rx_ctrl,
    input   logic [31:0]  i_rx_data,

    // Signals to MAC learner
    input   logic [3:0]  i_dst_port,
    input   logic        i_done,
    output  logic        o_valid,
    output  logic [3:0]  o_src_port,
    output  logic [47:0] o_dst_mac,
    output  logic [47:0] o_src_mac,

    // Signals to Cross-Bar
    output  logic [3:0]  o_packet_valid,
    output  logic [3:0]  o_dst_port         [3:0],
    output  logic [7:0]  o_data             [3:0],
    output  logic [10:0] o_packet_length    [3:0]
);

    // Internal wires
    logic [47:0] w_src_mac       [3:0];
    logic [47:0] w_dst_mac       [3:0];
    logic [10:0] w_packet_length [3:0];
    logic [3:0]  w_valid;
    logic [3:0]  w_status_empty;

    logic [3:0]  w_status_ren;
    logic [3:0]  w_length_ren;
    logic [3:0]  w_srcmac_ren;
    logic [3:0]  w_dstmac_ren;
    logic [3:0]  w_datafifo_ren;
    logic [3:0]  w_datafifo_full;

    // ----------------------------------------------------------------
    // CRC calculators — one per inbound port
    // ----------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_crc
            crc_calculator u_crc_calculator (
                .clk             ( i_clk                ),
                .reset           ( i_reset              ),
                .i_rx_ctrl       ( i_rx_ctrl[i] && !w_datafifo_full[i]), // Only write if data_fifo isn't full
                .i_data          ( i_rx_data[i*8 +: 8]  ), // Crc[0] gets [7:0], crc[1] gets [15:8], etc.
                .src_mac         ( w_src_mac[i]         ),
                .dst_mac         ( w_dst_mac[i]         ),
                .o_packet_length ( w_packet_length[i]   ),
                .o_valid         ( w_valid[i]           ),
                .i_status_ren    ( w_status_ren[i]      ),
                .i_length_ren    ( w_length_ren[i]      ),
                .i_srcmac_ren    ( w_srcmac_ren[i]      ),
                .i_dstmac_ren    ( w_dstmac_ren[i]      ),
                .o_status_empty  ( w_status_empty[i]    ),
                .o_length_empty  (),  // Unused fifo signals  // TODO WHY IS IT UNCONNECTED
                .o_srcmac_empty  (),                          // TODO WHY IS IT UNCONNECTED
                .o_dstmac_empty  ()                           // TODO WHY IS IT UNCONNECTED
            );  
        end
    endgenerate

    generate
        for (i = 0; i < 4; i++) begin : gen_data_fifo
            data_fifo data_fifo_inst (
                .clock  ( i_clk                              ),
                .data   ( i_rx_data[i*8 +: 8]                ),
                .wrreq  ( i_rx_ctrl[i] && !w_datafifo_full[i]), // Only write if fifo isn't full
                .rdreq  ( w_datafifo_ren[i]                  ),
                .full   ( w_datafifo_full[i]                 ),
                .empty  (                                    ),
                .q      ( o_data[i]                          )
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
        .o_src_port      ( o_src_port      ),
        .o_src_mac       ( o_src_mac       ),
        .o_dst_mac       ( o_dst_mac       ),
        .i_done          ( i_done          ),
        .i_dst_port      ( i_dst_port      ),
        // Crossbar
        .o_packet_valid  ( o_packet_valid  ),
        .o_dst_port      ( o_dst_port      ),
        .o_packet_length ( o_packet_length )
    );
    
endmodule