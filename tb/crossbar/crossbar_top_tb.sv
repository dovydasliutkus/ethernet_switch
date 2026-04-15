module crossbar_top_tb;
    // SIMPLE TESTBENCH (WILL BE REMOVED LATER)
    localparam PORTS = 4;
    localparam DATA_W = 8;
    localparam MAX_PKT_SIZE = 1518;
    localparam LEN_WIDTH = $clog2(MAX_PKT_SIZE);

    logic clk;
    logic rst;

    logic [PORTS*DATA_W-1:0] i_data;
    logic [PORTS-1:0] i_pkt_valid;
    logic [PORTS-1:0] i_dst_port [PORTS];
    logic [LEN_WIDTH-1:0] i_pkt_len [PORTS];

    logic [PORTS*DATA_W-1:0] o_tx_data;
    logic [PORTS-1:0] o_tx_ctrl;

    // DUT
    crossbar_top dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_data(i_data),
        .i_pkt_valid(i_pkt_valid),
        .i_dst_port(i_dst_port),
        .i_pkt_len(i_pkt_len),
        .o_tx_data(o_tx_data),
        .o_tx_ctrl(o_tx_ctrl)
    );

    // clock
    always #5 clk = ~clk;


    task automatic simple_test();

        i_data = 32'h000000aa; // data on input port 0
        i_pkt_valid = 4'b0001; // for input port 0
        i_dst_port[0] = 4'b0001; // to port 0
        i_pkt_len[0] = 8; // packet length from input port 0

        repeat(40) @(posedge clk);

    endtask


    initial begin
        clk = 0;
        rst = 0;

        repeat(5) @(posedge clk);
        rst = 1; // release reset

        simple_test();

        $finish;
    end
endmodule