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

    // clear inputs
    task clear_inputs();
        i_data = '0;
        i_pkt_valid = '0;
        for (int i = 0; i < PORTS; i++) begin
            i_dst_port[i] = '0;
            i_pkt_len[i]  = '0;
        end
    endtask

    ////////////// OUTPUT MONITOR ///////////////7
    always @(posedge clk) begin
        if (o_tx_ctrl != 0) begin
            $display("[%0t] OUTPUT:", $time);
            for (int j = 0; j < PORTS; j++) begin
                if (o_tx_ctrl[j]) begin
                    $display("  Port %0d -> Data = %h",
                        j, o_tx_data[j*DATA_W +: DATA_W]);
                end
            end
        end
    end

    initial begin
        clk = 0;
        rst = 0;
        clear_inputs();

        // reset
        repeat (5) @(posedge clk);
        rst = 1;

        $display("[%0t] Starting packet: input 0 -> output 2, length = 4", $time);

        // TEST: Input 0 -> Output 2
        i_pkt_len[0]  = 4;
        i_dst_port[0] = 4'b0100; // output 2

        // send 4 bytes
        for (int k = 0; k < 4; k++) begin
            @(posedge clk);
            i_pkt_valid[0] = 1;
            i_data[0*DATA_W +: DATA_W] = 8'hA0 + k;

            $display("[%0t] INPUT: port 0 sent %h",
                $time, 8'hA0 + k);
        end

        // end of packet
        @(posedge clk);
        i_pkt_valid[0] = 0;
        i_data = '0;

        $display("[%0t] Packet finished sending", $time);

        // wait for a while for the waveform
        repeat (30) @(posedge clk);

        $display("[%0t] Simulation done", $time);
        $finish;
    end

endmodule