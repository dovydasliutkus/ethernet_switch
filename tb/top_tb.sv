`timescale 1ns/1ps

// =============================================================================
// Testbench for switchcore (top-level integration)
//
// Sends Ethernet frames from a packet file.
//
// Checks (via hierarchical references into the DUT):
//   1.  packet_valid[port] asserts after the MAC lookup completes
//   2.  packet_valid[port] stays high for exactly `packet_length` cycles
// =============================================================================

module top_tb;

    // DUT signals
    logic        i_clk, i_reset;
    logic [31:0] tx_data;
    logic [3:0]  tx_ctrl;

    // Per-port intermediates merged into the DUT RX bus
    logic [3:0] port_rx_ctrl;
    logic [7:0] port_rx_data [3:0];
    logic [31:0] rx_data;
    logic [3:0]  rx_ctrl;

    always_comb begin
        rx_ctrl = port_rx_ctrl;
        rx_data = {port_rx_data[3], port_rx_data[2],
                   port_rx_data[1], port_rx_data[0]};
    end

    localparam string PACKET_FILE = "tb/packet.txt";

    // DUT — mac_learner is instantiated inside switchcore
    switchcore dut (
        .clk       ( i_clk   ),
        .reset     ( i_reset  ),
        .link_sync (),
        .tx_data   ( tx_data  ),
        .tx_ctrl   ( tx_ctrl  ),
        .rx_data   ( rx_data  ),
        .rx_ctrl   ( rx_ctrl  )
    );

    initial i_clk = 0;
    always #5 i_clk = ~i_clk;

    // ----------------------------------------------------------------
    // Packet storage
    // ----------------------------------------------------------------
    localparam MAX_BYTES   = 1600;
    localparam MAX_PACKETS = 32;

    logic [7:0] packets    [MAX_PACKETS][MAX_BYTES];
    int         pkt_lens   [MAX_PACKETS];
    int         num_packets;

    // ----------------------------------------------------------------
    // read_packet_file : parse hex bytes, "---" separates packets
    // ----------------------------------------------------------------
    task automatic read_packet_file(input string filename);
        int fd, pkt_idx, byte_idx, byte_val;
        string token;

        fd = $fopen(filename, "r");
        if (fd == 0) $fatal(1, "Cannot open: %s", filename);

        pkt_idx = 0; byte_idx = 0;

        while ($fscanf(fd, " %s", token) == 1) begin
            if (token == "---") begin
                pkt_lens[pkt_idx] = byte_idx;
                $display("Packet %0d: %0d bytes", pkt_idx, byte_idx);
                pkt_idx++; byte_idx = 0;
            end else begin
                if ($sscanf(token, "%h", byte_val) == 1)
                    packets[pkt_idx][byte_idx++] = byte_val[7:0];
                else
                    $fatal(1, "Bad token: %s", token);
            end
        end

        if (byte_idx > 0) begin
            pkt_lens[pkt_idx] = byte_idx;
            $display("Packet %0d: %0d bytes", pkt_idx, byte_idx);
            pkt_idx++;
        end

        num_packets = pkt_idx;
        $display("Total packets loaded: %0d\n", num_packets);
        $fclose(fd);
    endtask

    // ----------------------------------------------------------------
    // send_packet : drives one frame on `port`
    // ----------------------------------------------------------------
    task automatic send_packet(int pkt_idx, int port);
        int plen = pkt_lens[pkt_idx];
        $display("Sending packet %0d (%0d bytes) on port %0d", pkt_idx, plen, port);

        for (int b = 0; b < plen; b++) begin
            @(negedge i_clk);
            port_rx_ctrl[port] = 1'b1;
            port_rx_data[port] = packets[pkt_idx][b];
        end

        @(posedge i_clk);
        @(negedge i_clk);
        port_rx_ctrl[port] = 1'b0;
        port_rx_data[port] = 8'b0;
    endtask

    // ----------------------------------------------------------------
    // check_packet : waits for packet_valid[port] then counts cycles.
    //   Uses hierarchical references since packet_valid is internal to
    //   switchcore (crossbar not yet instantiated as a top-level output).
    //   `port` is the INPUT port index — packet_valid is indexed by it.
    //   Timeout is generous to accommodate the 2-cycle mac_learner FSM
    //   plus CRC/FIFO latency.
    // ----------------------------------------------------------------
    task automatic check_packet(int pkt_idx, int port);
        int tx_cycles, timeout, pass;
        pass = 1;

        begin : wait_tx
            timeout = 0;
            while (!dut.packet_valid[port]) begin
                @(posedge i_clk);
                if (++timeout > 200) begin
                    $display("  FAIL packet_valid[%0d] never asserted", port);
                    pass = 0;
                    disable wait_tx;
                end
            end
        end

        tx_cycles = 0;
        while (dut.packet_valid[port]) begin
            tx_cycles++;
            @(posedge i_clk);
        end

        if (tx_cycles !== pkt_lens[pkt_idx]) begin
            $display("  FAIL tx_cycles : got %0d, expected %0d",
                     tx_cycles, pkt_lens[pkt_idx]);
            pass = 0;
        end else
            $display("  PASS tx_cycles : %0d", tx_cycles);

        if (pass)
            $display("=== Packet %0d: ALL CHECKS PASSED ===\n", pkt_idx);
        else
            $display("=== Packet %0d: CHECKS FAILED ===\n", pkt_idx);
    endtask

    // ----------------------------------------------------------------
    // Main stimulus
    // ----------------------------------------------------------------
    initial begin
        i_reset      = 1'b1;
        port_rx_ctrl = 4'b0;
        foreach (port_rx_data[p]) port_rx_data[p] = 8'b0;

        repeat(4) @(posedge i_clk);
        i_reset = 1'b0;
        repeat(2) @(posedge i_clk);

        read_packet_file(PACKET_FILE);

        for (int p = 0; p + 1 < num_packets; p += 2) begin
            
            // // Parallel implementation
            // fork
            //     send_packet(p,   0);
            //     send_packet(p+1, 1);
            // join
            // fork
            //     check_packet(p,   0);
            //     check_packet(p+1, 1);
            // join

            send_packet(p, 0);
            check_packet(p, 0);

            send_packet(p+1, 1);
            check_packet(p+1, 1);

            repeat(4) @(posedge i_clk);
        end

        if (num_packets % 2 == 1) begin
            send_packet(num_packets - 1, 0);
            check_packet(num_packets - 1, 0);
            repeat(4) @(posedge i_clk);
        end

        $display("Simulation complete.");
        $stop;
    end

endmodule
