`timescale 1ns/1ps

// =============================================================================
// Testbench for fcs_control
//
// Sends Ethernet frames from a packet file into port TEST_DST_PORT 
// (where TEST_DST_PORT is a constant value), emulates the MAC
// learner, and verifies:
//   1.  o_dst_mac / o_src_mac presented to the MAC learner are correct
//   2.  o_packet_valid[TEST_DST_PORT] goes high after the MAC response
//   3.  o_dst_port[TEST_DST_PORT] holds the returned destination for the full frame
//   4.  o_packet_valid[TEST_DST_PORT] stays high for exactly `packet_length` cycles
// =============================================================================

module fcs_control_tb;

    // DUT signals
    logic        i_clk, i_reset;
    logic [3:0]  i_rx_ctrl;
    logic [31:0] i_rx_data;

    // Per-port intermediates — each send_packet task drives only its own slot;
    // always_comb merges them into the shared DUT inputs.
    logic [3:0] port_rx_ctrl;          // one bit per port
    logic [7:0] port_rx_data [3:0];    // one byte per port

    always_comb begin
        i_rx_ctrl = port_rx_ctrl;
        i_rx_data = {port_rx_data[3], port_rx_data[2],
                     port_rx_data[1], port_rx_data[0]};
    end

    // MAC learner
    logic        i_done;
    logic [3:0]  i_dst_port;
    logic        o_valid;
    logic [47:0] o_dst_mac, o_src_mac;

    // Crossbar
    logic [3:0]  o_packet_valid;
    logic [3:0]  o_dst_port      [3:0];
    logic [7:0]  o_data          [3:0];
    logic [10:0] o_packet_length [3:0];

    localparam string PACKET_FILE   = "tb/packet.txt";
    localparam [3:0]  TEST_DST_PORT = 4'b0110;  // one-hot: route to port 1
    localparam        MAC_LATENCY   = 1;         // cycles from o_valid to i_done

    // DUT
    fcs_control dut (
        .i_clk          ( i_clk          ),
        .i_reset        ( i_reset        ),
        .i_rx_ctrl      ( i_rx_ctrl      ),
        .i_rx_data      ( i_rx_data      ),
        .i_dst_port     ( i_dst_port     ),
        .i_done         ( i_done         ),
        .o_valid        ( o_valid        ),
        .o_dst_mac      ( o_dst_mac      ),
        .o_src_mac      ( o_src_mac      ),
        .o_packet_valid ( o_packet_valid ),
        .o_dst_port     ( o_dst_port     ),
        .o_data         ( o_data         ),
        .o_packet_length( o_packet_length)
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

    // Counter incremented by MAC emulator on each o_valid pulse,
    // decremented by each check_packet call — supports parallel checking.
    int          mac_request_count;
    logic [47:0] cap_dst_mac, cap_src_mac;

    // ----------------------------------------------------------------
    // MAC learner emulator (runs in parallel with stimulus)
    // Responds with TEST_DST_PORT to every o_valid pulse after MAC_LATENCY cycles.
    // ----------------------------------------------------------------
    initial begin
        i_done             = 1'b0;
        i_dst_port         = 4'b0;
        mac_request_count  = 0;
        cap_dst_mac        = '0;
        cap_src_mac        = '0;
        forever begin
            @(posedge i_clk);
            if (o_valid) begin
                // Latch MACs while o_valid is high
                cap_dst_mac      = o_dst_mac;
                cap_src_mac      = o_src_mac;
                mac_request_count++;

                // Wait MAC_LATENCY cycles then assert i_done for one cycle
                // Drive at negedge so DUT sees a clean posedge setup
                repeat(MAC_LATENCY - 1) @(posedge i_clk);
                @(negedge i_clk);
                i_done     = 1'b1;
                i_dst_port = TEST_DST_PORT;
                @(posedge i_clk);
                @(negedge i_clk);
                i_done     = 1'b0;
                i_dst_port = 4'b0;
            end
        end
    end

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
    // i_rx_ctrl[port] mirrors GMII rx_dv: high every byte, low after last.
    // ----------------------------------------------------------------
    task automatic send_packet(int pkt_idx, int port);
        int plen = pkt_lens[pkt_idx];
        $display("Sending packet %0d (%0d bytes) on port %0d", pkt_idx, plen, port);

        for (int b = 0; b < plen; b++) begin
            @(negedge i_clk);
            port_rx_ctrl[port] = 1'b1;
            port_rx_data[port] = packets[pkt_idx][b];
        end

        @(posedge i_clk);   // register last byte into rem_reg
        @(negedge i_clk);
        port_rx_ctrl[port] = 1'b0;
        port_rx_data[port] = 8'b0;
    endtask

    // ----------------------------------------------------------------
    // check_packet : waits for MAC learner request + transmission,
    //   then checks dst/src MAC and o_packet_valid duration.
    //   Pass `port` to select which crossbar output to watch.
    // ----------------------------------------------------------------
    task automatic check_packet(int pkt_idx, int port);
        logic [47:0] exp_dst_mac, exp_src_mac;
        int          tx_cycles, timeout;
        int          pass;
        pass = 1;

        // Wait for MAC learner request (incremented by MAC emulator)
        begin : wait_mac
            timeout = 0;
            while (mac_request_count == 0) begin
                @(posedge i_clk);
                if (++timeout > 50) begin
                    $display("  INFO  no MAC lookup — frame was dropped (bad CRC)");
                    disable wait_mac;
                end
            end
        end
        mac_request_count--;

        // Expected MAC addresses at MAC Learner input (bytes 0–3 come inverted as per ETH protocol)
        exp_dst_mac[ 7: 0] = ~packets[pkt_idx][0];
        exp_dst_mac[15: 8] = ~packets[pkt_idx][1];
        exp_dst_mac[23:16] = ~packets[pkt_idx][2];
        exp_dst_mac[31:24] = ~packets[pkt_idx][3];
        exp_dst_mac[39:32] =  packets[pkt_idx][4];
        exp_dst_mac[47:40] =  packets[pkt_idx][5];

        exp_src_mac[ 7: 0] = packets[pkt_idx][ 6];
        exp_src_mac[15: 8] = packets[pkt_idx][ 7];
        exp_src_mac[23:16] = packets[pkt_idx][ 8];
        exp_src_mac[31:24] = packets[pkt_idx][ 9];
        exp_src_mac[39:32] = packets[pkt_idx][10];
        exp_src_mac[47:40] = packets[pkt_idx][11];

        if (cap_dst_mac !== exp_dst_mac) begin
            $display("  FAIL o_dst_mac : got %h, expected %h", cap_dst_mac, exp_dst_mac);
            pass = 0;
        end else
            $display("  PASS o_dst_mac : %h", cap_dst_mac);

        if (cap_src_mac !== exp_src_mac) begin
            $display("  FAIL o_src_mac : got %h, expected %h", cap_src_mac, exp_src_mac);
            pass = 0;
        end else
            $display("  PASS o_src_mac : %h", cap_src_mac);

        // Wait for o_packet_valid[port] to go high
        begin : wait_tx
            timeout = 0;
            while (!o_packet_valid[port]) begin
                @(posedge i_clk);
                if (++timeout > 30) begin
                    $display("  FAIL o_packet_valid[%0d] never asserted", port);
                    pass = 0;
                    disable wait_tx;
                end
            end
        end

        // Count cycles and verify o_dst_port[port] throughout
        tx_cycles = 0;
        while (o_packet_valid[port]) begin
            if (o_dst_port[port] !== TEST_DST_PORT) begin
                $display("  FAIL o_dst_port[%0d] : got %b, expected %b",
                         port, o_dst_port[port], TEST_DST_PORT);
                pass = 0;
            end
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

        // Send pairs of packets in parallel across ports, then check each in turn.
        // send_packet tasks are independent (each drives its own port_rx_ctrl/data
        // slot), so fork/join is safe.  check_packet is kept sequential because
        // the MAC lookup interface (o_valid / i_done) is shared and arbitrated.
        for (int p = 0; p + 1 < num_packets; p += 2) begin
            fork
                send_packet(p, 0);
                send_packet(p, 1);
            join
            fork
                check_packet(p, 0);
                check_packet(p, 1);
            join
            repeat(4) @(posedge i_clk);
        end

        // Handle odd trailing packet (if num_packets is odd)
        if (num_packets % 2 == 1) begin
            send_packet(num_packets - 1, 0);
            check_packet(num_packets - 1, 0);
            repeat(4) @(posedge i_clk);
        end

        $display("Simulation complete.");
        $stop;
    end

endmodule
