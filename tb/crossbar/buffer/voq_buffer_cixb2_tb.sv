import voq_buffer_pkg::*;

module voq_buffer_cixb2_tb;

    parameter DATA_W = 8;
    parameter PORTS = 4;

    logic clk = 0;

    // interface and class instance
    voq_buffer_if #(.DATA_W(DATA_W), .PORTS(PORTS)) vif(.clk(clk));
    voq_buffer_class drv;

    initial begin
        drv = new(vif);
    end

    // DUT
    voq_buffer_cixb2 dut (
        .i_clk(clk),
        .i_rst(vif.rst),
        .i_data(vif.data),
        .i_write_enable(vif.write_enable),
        .i_read_enable(vif.read_enable),
        .o_tx_data(vif.tx_data),
        .o_tx_ctrl(vif.tx_ctrl),
        .o_occupancy(vif.occupancy),
        .o_full(vif.full),
        .o_empty(vif.empty)
    );  

    //////////////// Clock ///////////////////////
    initial begin
        forever begin
            #5; 
            clk = ~clk;
        end
    end

    //////////////// Test tasks ////////////////////

    // Test 1: Single write and read
    task automatic test_single();
        logic [7:0] expected = 8'hAA; // from port 0 to port 1 (0, 1)
        logic [7:0] actual;

        drv.write(0,1,expected);
        @(vif.cb);

        drv.read(0,1);
        repeat (2) @(vif.cb);

        actual = vif.tx_data[1*DATA_W +: DATA_W];

        if (actual !== expected)
            $error("FAIL: expected 0x%0h got 0x%0h", expected, actual);
        else
            $display("PASS: single write/read");
    endtask

    // Test 2: Multiple writes and reads
    task automatic test_multiple();


    endtask



    //////////////// Run all tests ////////////////
    initial begin
        // reset the DUT
        drv.reset_sequence();

        // single write/read test
        test_single();
        $finish;
    end

endmodule