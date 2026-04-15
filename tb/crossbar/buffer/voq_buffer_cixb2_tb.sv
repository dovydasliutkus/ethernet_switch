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
    task automatic test_single_1();
        logic [7:0] expected_data = 8'hAA; // from port 0 to port 1 (0, 1)
        logic [7:0] actual_data;
        logic [11:0] occupancy_expected = 1;
        logic [11:0] occupancy_actual; 

        drv.write(0,1,expected_data);
        @(vif.cb);
        occupancy_actual = vif.occupancy[((0*PORTS + 1)*$clog2(4096)) +: $clog2(4096)];

        // throw error if occupancy is not 1 after write + clock cycle
        if (occupancy_actual !== occupancy_expected) begin
            $error("FAIL: expected occupancy %0d got %0d", occupancy_expected, occupancy_actual);
        end

        // throw error if fifo empty signal is not 0 after write + clock cycle
        if (vif.empty[0*PORTS + 1] !== 0) begin
            $error("FAIL: expected empty signal to be 0, got %0b", vif.empty[0*PORTS + 1]);
        end

        // throw error if fifo full signal is not 0 after write + clock cycle
        if (vif.full[0*PORTS + 1] !== 0) begin
            $error("FAIL: expected full signal to be 0, got %0b", vif.full[0*PORTS + 1]);
        end

        drv.read(0,1);
        @(vif.cb);
        actual_data = vif.tx_data[1*DATA_W +: DATA_W];

        if (actual_data !== expected_data || vif.tx_ctrl[1] !== 1)
            $error("FAIL: expected 0x%0h got 0x%0h. Full data is 0x%0h", expected_data, actual_data, vif.tx_data);
        else
            $display("PASS: single write/read");
    endtask

  // Test 2: Single write and read
    task automatic test_single_2();
        logic [7:0] expected_data = 8'hAA; // from port 1 to port 3 (1, 3)
        logic [7:0] actual_data;
        logic [11:0] occupancy_expected = 1;
        logic [11:0] occupancy_actual; 

        drv.write(1,3,expected_data);
        @(vif.cb);
        occupancy_actual = vif.occupancy[((1*PORTS + 3)*$clog2(4096)) +: $clog2(4096)];

        // throw error if occupancy is not 1 after write + clock cycle
        if (occupancy_actual !== occupancy_expected) begin
            $error("FAIL: expected occupancy %0d got %0d", occupancy_expected, occupancy_actual);
        end

        // throw error if fifo empty signal is not 0 after write + clock cycle
        if (vif.empty[1*PORTS + 3] !== 0) begin
            $error("FAIL: expected empty signal to be 0, got %0b", vif.empty[1*PORTS + 3]);
        end

        // throw error if fifo full signal is not 0 after write + clock cycle
        if (vif.full[1*PORTS + 3] !== 0) begin
            $error("FAIL: expected full signal to be 0, got %0b", vif.full[1*PORTS + 3]);
        end

        drv.read(1,3);
        @(vif.cb);
        actual_data = vif.tx_data[3*DATA_W +: DATA_W];

        if (actual_data !== expected_data || vif.tx_ctrl[3] !== 1)
            $error("FAIL: expected 0x%0h got 0x%0h. Full data is 0x%0h", expected_data, actual_data, vif.tx_data);
        else
            $display("PASS: single write/read");
    endtask

    //////////////// Run all tests ////////////////
    initial begin
        // reset the DUT
        drv.reset_sequence();

        // single write/read test
        test_single_1();
        test_single_2();
        $finish;
    end

    initial begin
        forever begin
            @(vif.cb);
            $display("[%0t] tx_data: 0x%0h", $time, vif.tx_data);
        end
    end

endmodule