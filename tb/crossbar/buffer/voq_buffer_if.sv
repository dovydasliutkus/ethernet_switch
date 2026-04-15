interface voq_buffer_if #(parameter DATA_W = 8, PORTS = 4) (input logic clk);

    logic rst;

    logic [PORTS*DATA_W-1:0] data;
    logic [PORTS*PORTS-1:0] write_enable;
    logic [PORTS*PORTS-1:0] read_enable;

    logic [PORTS*DATA_W-1:0] tx_data;
    logic [PORTS-1:0] tx_ctrl;
    parameter OCC_WIDTH = $clog2(4096);
    logic [PORTS*PORTS*OCC_WIDTH-1:0] occupancy;
    logic [PORTS*PORTS-1:0] full;
    logic [PORTS*PORTS-1:0] empty;

    clocking cb @(posedge clk);
        output data;
        output write_enable;
        output read_enable;

        input tx_data;
        input tx_ctrl;
        input occupancy;
    endclocking

endinterface

