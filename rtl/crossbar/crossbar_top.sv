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
    input logic [PORTS-1:0] i_dst_port [PORTS],
    input logic [LEN_WIDTH-1:0] i_pkt_len [PORTS],

    // Outputs
    output logic [PORTS*DATA_W-1:0] o_tx_data,
    output logic [PORTS-1:0] o_tx_ctrl
); 

    //////////////////// Buffer instantantiation ////////////////////
    // Signals
    logic [PORTS*PORTS*OCC_WIDTH-1:0] occupancy;
    logic [PORTS*PORTS-1:0] full;
    logic [PORTS*PORTS-1:0] empty;
    logic [PORTS*PORTS-1:0] write_enable;
    logic [PORTS*PORTS-1:0] read_enable;
    logic [OCC_WIDTH-1:0] usedw [PORTS][PORTS];

    logic [PORTS-1:0] buffer_wr_en [PORTS];
    logic [PORTS-1:0] buffer_rd_en [PORTS];
    logic [PORTS-1:0] buffer_full [PORTS];
    logic [PORTS-1:0] buffer_empty [PORTS];

    // // Concatenate read and write enable from each scheduler
    // assign write_enable = {buffer_wr_en[3], buffer_wr_en[2], buffer_wr_en[1], buffer_wr_en[0]};
    // assign read_enable = {buffer_rd_en[3], buffer_rd_en[2], buffer_rd_en[1], buffer_rd_en[0]};

    always_comb begin
        for (int i = 0; i < PORTS; i++) begin          // input port
            for (int j = 0; j < PORTS; j++) begin      // output port
                write_enable[i*PORTS + j] = buffer_wr_en[i][j];
                read_enable[i*PORTS + j]  = buffer_rd_en[i][j];
            end
        end
    end

    voq_buffer_cixb2  #(.DATA_W(DATA_W), .PORTS(PORTS), .FIFO_DEPTH(FIFO_DEPTH)
    ) u_voq_buffer_cixb2 (
        .i_clk(i_clk),
        .i_rst(i_rst),

        .i_data(i_data),

        .i_write_enable(write_enable), // 16-bit flat array, 4 bits per port
        .i_read_enable(read_enable),   // 16-bit flat array, 4 bits per port

        .o_tx_data(o_tx_data),
        .o_tx_ctrl(o_tx_ctrl),

        .o_occupancy(occupancy),
        .o_full(full),
        .o_empty(empty)
    );
    // Extract occupancy
    always_comb begin
        for (int i = 0; i < PORTS; i++) begin           // input port
            for (int j = 0; j < PORTS; j++) begin       // output port
                usedw[i][j] = occupancy[((i*PORTS + j)*OCC_WIDTH) +: OCC_WIDTH];
            end
        end
    end

    // Extract full and empty signals for each buffer
    always_comb begin
        for (int i = 0; i < PORTS; i++) begin
            for (int j = 0; j < PORTS; j++) begin
                buffer_full[i][j]  = full[i*PORTS + j];
                buffer_empty[i][j] = empty[i*PORTS + j];
            end
        end
    end
    ////////////////// Scheduler instantiation //////////////////////
    // Generates four schedulers, one for each output port
    // Signals
    logic [OCC_WIDTH-1:0] col_usedw [PORTS][PORTS];
    logic [PORTS-1:0] col_full [PORTS];
    logic [PORTS-1:0] col_empty [PORTS];

    always_comb begin
        for (int j = 0; j < PORTS; j++) begin          // output port
            for (int i = 0; i < PORTS; i++) begin      // input port
                col_usedw[j][i] = usedw[i][j];
                col_full[j][i]  = buffer_full[i][j];
                col_empty[j][i] = buffer_empty[i][j];
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < PORTS; i++) begin
                drr_scheduler # (.PORT_ID(i), .MAX_PKT_SIZE(MAX_PKT_SIZE),
                                               .LEN_WIDTH(LEN_WIDTH), .FIFO_DEPTH(FIFO_DEPTH), .OCC_WIDTH(OCC_WIDTH)
                        ) u_drr_scheduler (
                        .i_clk(i_clk),
                        .i_reset(i_rst),
                        .i_pkt_valid(i_pkt_valid),
                        .i_dst_port(i_dst_port),
                        .i_pkt_len(i_pkt_len),
                        .i_buffer_usedw(col_usedw[i]),
                        .i_buffer_full(col_full[i]),
                        .i_buffer_empty(col_empty[i]),
                        .o_buffer_wr_en(buffer_wr_en[i]),
                        .o_buffer_rd_en(buffer_rd_en[i])
                    );

        end
    endgenerate

endmodule  
