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


    logic [PORTS*PORTS-1:0] write_enable;
    logic [PORTS*PORTS-1:0] read_enable;

    logic [PORTS*PORTS-1:0] full;
    logic [PORTS*PORTS-1:0] empty;
    logic [PORTS*PORTS*OCC_WIDTH-1:0] occupancy;


    logic [PORTS-1:0] buffer_wr_en [PORTS-1:0];
    logic [PORTS-1:0] buffer_rd_en [PORTS-1:0];

    always_comb begin
        for (int i = 0; i < PORTS; i++) begin
            for (int j = 0; j < PORTS; j++) begin
                write_enable[i*PORTS + j] = buffer_wr_en[j][i];
                read_enable[i*PORTS + j]  = buffer_rd_en[j][i];
                
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
 

    genvar i;

    logic [OCC_WIDTH-1:0] usedw_col [PORTS][PORTS]; // [j][i]
    logic [PORTS-1:0]     full_col [PORTS]; // [j][i]
    logic [PORTS-1:0]     empty_col [PORTS]; // [j][i]

    always_comb begin
        for (int i = 0; i < PORTS; i++) begin
            for (int j = 0; j < PORTS; j++) begin
                automatic int idx = i*PORTS + j;
                // transpose: [i][j] becomes [j][i]
                usedw_col[j][i] = occupancy[idx*OCC_WIDTH +: OCC_WIDTH];
                full_col[j][i]  = full[idx];
                empty_col[j][i] = empty[idx];
            end
        end
    end

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
                .i_buffer_usedw(usedw_col[i]),
                .i_buffer_full(full_col[i]),
                .i_buffer_empty(empty_col[i]),
                .o_buffer_wr_en(buffer_wr_en[i]),
                .o_buffer_rd_en(buffer_rd_en[i])
            );
        end
    endgenerate

endmodule  
