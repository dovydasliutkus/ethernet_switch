module crossbar_top #(
    parameter int DATA_W = 8,
    parameter int PORTS = 4,
    parameter int FIFO_DEPTH = 4096,
    parameter int PORT_ID       = 0,                    // which output port schedueler manages (0-3)
    parameter int MAX_PKT_SIZE  = 1518,                 // Bytes of credit added per DRR turn
    parameter int LEN_WIDTH     = $clog2(MAX_PKT_SIZE), // Packet length field width (for max. 1518 byte packet)
    parameter int OCC_WIDTH     = $clog2(FIFO_DEPTH)    // Occupancy width from Quartus FIFO IP
)(
    // Inputs from FCS and Control
    input logic i_clk,
    input logic i_rst,
    input logic [DATA_W-1:0]  i_data,

    input logic [PORTS-1:0] i_pkt_valid,
    input logic [PORTS-1:0] i_dst_port [PORTS],
    input logic [LEN_WIDTH-1:0] i_pkt_len [PORTS],

    // Outputs
    output logic [PORTS*DATA_W-1:0] o_tx_data,
    output logic [PORTS-1:0] o_tx_ctrl
); 

    //////////////////// Buffer instantantiation ////////////////////
    // Signals
    logic occupancy [PORTS*PORTS-1:0]; // todo WRONG
    logic full [PORTS*PORTS-1:0];
    logic empty [PORTS*PORTS-1:0];
    logic write_enable [PORTS*PORTS-1:0];
    logic read_enable [PORTS*PORTS-1:0];

    logic [PORTS-1:0] buffer_wr_en [PORTS];
    logic [PORTS-1:0] buffer_rd_en [PORTS];
    logic [PORTS-1:0] buffer_full [PORTS];
    logic [PORTS-1:0] buffer_empty [PORTS];

    // Concatenate read and write enable from each scheduler
    assign write_enable = {buffer_wr_en[3], buffer_wr_en[2], buffer_wr_en[1], buffer_wr_en[0]};
    assign read_enable = {buffer_rd_en[3], buffer_rd_en[2], buffer_rd_en[1], buffer_rd_en[0]};

    voq_buffer_cixb2 u_voq_buffer_cixb2 #(.DATA_W(DATA_W), .PORTS(PORTS), .FIFO_DEPTH(FIFO_DEPTH))(
        .i_clk(i_clk),
        .i_rst(i_rst),

        .i_data(i_data),

        .i_write_enable(write_enable), // 16-bit flat array, 4 bits per port
        .i_read_enable(read_enable),   // 16-bit flat array, 4 bits per port

        .o_tx_data(o_tx_data),
        .o_tx_ctrl(o_tx_ctrl),

        .o_occupancy(occupancy), // TODO WRONG
        .o_full(full),
        .o_empty(empty)
    );
    // Extract occupancy and buffer empty/full for each output port
    always_comb begin
        for (i = 0; i < PORTS; i++) begin
            assign usedw[i] = occupancy[(i+1)*PORTS-1 -: PORTS]; // TODO WRONG
            assign buffer_full[i] = full[(i+1)*PORTS-1 -: PORTS];
            assign buffer_empty[i] = empty[(i+1)*PORTS-1 -: PORTS];
        end
    end

    ////////////////// Scheduler instantiation //////////////////////
    // Generates four schedulers, one for each output port
    // Signals
    logic [PORTS-1:0] dst_port [PORTS];

    genvar i;
    generate
        for (i = 0; i < PORTS; i++) begin
                drr_scheduler u_drr_scheduler (.PORT_ID(PORT_ID), .MAX_PKT_SIZE(MAX_PKT_SIZE),
                                               .LEN_WIDTH(LEN_WIDTH), .FIFO_DEPTH(FIFO_DEPTH), .OCC_WIDTH(OCC_WIDTH))(
                        .i_clk(i_clk),
                        .i_reset(i_rst),
                        .i_pkt_valid(i_pkt_valid),
                        .i_dst_port(dst_port[i]),
                        .i_buffer_usedw(usedw[i]),
                        .i_buffer_full(buffer_full[i]),
                        .i_buffer_empty(buffer_empty[i]),
                        .o_buffer_wr_en(buffer_wr_en[i]),
                        .o_buffer_rd_en(buffer_rd_en[i])
                    );

        end
    endgenerate

endmodule  
