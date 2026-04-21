interface crossbar_if #(parameter DATA_W=8, PORTS=4, LEN_WIDTH=11)
    (input logic clk);

    logic rst;

    logic [PORTS*DATA_W-1:0] data;
    logic [PORTS-1:0] pkt_valid;
    logic [PORTS-1:0] dst_port [PORTS-1:0];
    logic [LEN_WIDTH-1:0] pkt_len [PORTS-1:0];

    logic [PORTS*DATA_W-1:0] tx_data;
    logic [PORTS-1:0] tx_ctrl;

    clocking cb @(posedge clk);

        output data;
        output pkt_valid;
        output dst_port;
        output pkt_len;

        input tx_data;
        input tx_ctrl;

    endclocking


endinterface