module voq_buffer_cixb2 #(
    parameter int DATA_W = 8,
    parameter int PORTS = 4,
    parameter int FIFO_DEPTH = 4096,  // enough for 2 packets of 1518 bytes
    parameter int OCC_WIDTH = $clog2(FIFO_DEPTH)
)(

    input logic i_clk,
    input logic i_rst,

    input logic [PORTS*DATA_W-1:0] i_data,

    input logic [PORTS*PORTS-1:0] i_write_enable,
    input logic [PORTS*PORTS-1:0] i_read_enable,

    output logic [PORTS*DATA_W-1:0] o_tx_data,
    output logic [PORTS-1:0] o_tx_ctrl,

    output logic [PORTS*PORTS*OCC_WIDTH-1:0] o_occupancy,
    output logic [PORTS*PORTS-1:0] o_full,
    output logic [PORTS*PORTS-1:0] o_empty
);
    //////////////// Internal signals ////////////////
    logic [DATA_W-1:0] fifo_wdata [PORTS][PORTS];
    logic fifo_wen [PORTS][PORTS];
    logic fifo_ren [PORTS][PORTS];
    logic [DATA_W-1:0] fifo_rdata [PORTS][PORTS];
    logic fifo_empty [PORTS][PORTS];
    logic fifo_full [PORTS][PORTS];
    logic [OCC_WIDTH-1:0] fifo_usedw [PORTS][PORTS];

    logic [PORTS*DATA_W-1:0] o_tx_data_r;
    logic [PORTS-1:0] o_tx_ctrl_r;

    logic [PORTS*DATA_W-1:0] o_tx_data_next;
    logic [PORTS-1:0] o_tx_ctrl_next;

    // Generate the 16 fifos for the crossbar
    genvar i, j;
    generate
        for (i = 0; i < PORTS; i++) begin : ROW
            for (j = 0; j < PORTS; j++) begin : COL

                fifo fifo_inst (
                    .clock (i_clk),

                    .data (fifo_wdata[i][j]),
                    .wrreq (fifo_wen[i][j]),
                    .rdreq (fifo_ren[i][j]),

                    .q (fifo_rdata[i][j]),
                    .full (fifo_full[i][j]),
                    .empty (fifo_empty[i][j]),
                    .usedw (fifo_usedw[i][j])
                );

            end
        end
    endgenerate
    ////////////////////////////////////////////////////

    ///////// Read/Write and data connections //////////
    always_comb begin
        for (int i = 0; i < PORTS; i++) begin // ROW
            for (int j = 0; j < PORTS; j++) begin // COLUNB
                // connect scheduler to FIFO control
                fifo_wen[i][j] = i_write_enable[i*PORTS + j];
                fifo_ren[i][j] = i_read_enable[i*PORTS + j];

                // each row gets its input data
                fifo_wdata[i][j] = i_data[i*DATA_W +: DATA_W];
            end
        end
    end
    ///////////////////////////////////////////////////

    /////////// Status output flattening //////////////
    always_comb begin

        for (int i = 0; i < PORTS; i++) begin
            for (int j = 0; j < PORTS; j++) begin
                automatic int idx = i*PORTS + j;
                o_occupancy[idx*OCC_WIDTH +: OCC_WIDTH] = fifo_usedw[i][j];
                o_full[i*PORTS + j] = fifo_full[i][j];
                o_empty[i*PORTS + j] = fifo_empty[i][j];
            end
        end
    end
    ///////////////////////////////////////////////////

    logic [PORTS*PORTS-1:0] read_enable_d;

    always_ff @(posedge i_clk) begin
        read_enable_d <= i_read_enable;
    end
    always_comb begin
        o_tx_data_next = '0;
        o_tx_ctrl_next = '0;

        for (int j = 0; j < PORTS; j++) begin
            for (int i = 0; i < PORTS; i++) begin
                if (read_enable_d[i*PORTS + j]) begin
                    o_tx_data_next[j*DATA_W +: DATA_W] = fifo_rdata[i][j];
                    o_tx_ctrl_next[j] = 1'b1;
                end
            end
        end
    end
    //////////////////////////////////////////////////

    //////////////// Output registers ////////////////
    always_ff @(posedge i_clk) begin
        if (!i_rst) begin
            o_tx_data_r  <= '0;
            o_tx_ctrl_r <= '0;
        end else begin
            o_tx_data_r  <= o_tx_data_next;
            o_tx_ctrl_r <= o_tx_ctrl_next;
        end
    end
    assign o_tx_data  = o_tx_data_r;
    assign o_tx_ctrl = o_tx_ctrl_r;
    /////////////////////////////////////////////////
endmodule