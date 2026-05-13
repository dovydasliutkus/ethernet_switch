module crossbar_top #(
    parameter int DATA_W = 8,
    parameter int PORTS = 4,
    parameter int FIFO_DEPTH = 4096,
    parameter int MAX_PKT_SIZE  = 1518,                 // Bytes of credit added per DRR turn
    parameter int LEN_WIDTH     = $clog2(MAX_PKT_SIZE), // Packet length field width (for max. 1518 byte packet)
    parameter int OCC_WIDTH     = $clog2(FIFO_DEPTH)    // Occupancy width from Quartus FIFO IP
)(
    // Inputs from FCS and Control
    input logic i_clk,
    input logic i_rst,
    input logic [PORTS*DATA_W-1:0] i_data,

    input logic [PORTS-1:0] i_pkt_valid,
    input logic [PORTS-1:0] i_dst_port [PORTS-1:0],
    input logic [LEN_WIDTH-1:0] i_pkt_len [PORTS-1:0],

    // Outputs
    output logic [PORTS*DATA_W-1:0] o_tx_data,
    output logic [PORTS-1:0] o_tx_ctrl
); 


    logic [PORTS*PORTS-1:0] full;
    logic [PORTS*PORTS-1:0] empty;
    logic [PORTS*PORTS*OCC_WIDTH-1:0] occupancy;

    logic [PORTS-1:0] buffer_wr_en [PORTS-1:0];
    logic [PORTS-1:0] buffer_rd_en [PORTS-1:0];

    voq_buffer_cixb2  #(.DATA_W(DATA_W), .PORTS(PORTS), .FIFO_DEPTH(FIFO_DEPTH)
    ) u_voq_buffer_cixb2 (
        .i_clk(i_clk),
        .i_rst(i_rst),

        .i_data(i_data),

        .i_write_enable(buffer_wr_en),
        .i_read_enable(buffer_rd_en),

        .o_tx_data(o_tx_data),
        .o_tx_ctrl(o_tx_ctrl),

        .o_occupancy(occupancy),
        .o_full(full),
        .o_empty(empty)
    );
 

    genvar i;

    generate
        for (i = 0; i < PORTS; i++) begin : gen_sched
            drr_scheduler #(
                .PORT_ID(i),
                .MAX_PKT_SIZE(MAX_PKT_SIZE),
                .LEN_WIDTH(LEN_WIDTH),
                .FIFO_DEPTH(FIFO_DEPTH),
                .OCC_WIDTH(OCC_WIDTH)
            ) u_drr_scheduler (
                .i_clk(i_clk),
                .i_reset(i_rst),
                .i_pkt_valid(i_pkt_valid),
                .i_dst_port(i_dst_port),
                .i_pkt_len(i_pkt_len),
                .i_buffer_usedw(occupancy[i*PORTS*OCC_WIDTH +: PORTS*OCC_WIDTH]),
                .i_buffer_full(full[i*PORTS +: PORTS]),
                .i_buffer_empty(empty[i*PORTS +: PORTS]),
                .o_buffer_wr_en(buffer_wr_en[i]),
                .o_buffer_rd_en(buffer_rd_en[i])
            );
        end
    endgenerate

endmodule  
