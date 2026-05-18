`timescale 1ns/1ps

// =============================================================================
// Testbench for switchcore (top-level integration)
//
// Sends Ethernet frames from a packet file.
//
// NOTE: packet.txt must contain valid Ethernet frames with correct FCS bytes.
//       Frames with bad CRC are silently dropped by fcs_control and will not
//       appear on tx_data / tx_ctrl.
//
// Checks (on crossbar output tx_data / tx_ctrl):
//   2.  Reports which output port(s) fired per packet
//   4.  Asserts tx_ctrl[ingress_port] never goes high (no self-loop)
//   5.  Asserts byte count per output port matches expected packet length
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

    // How many consecutive idle cycles before declaring output done.
    // Covers DRR scheduler gaps between output ports for broadcast frames.
    localparam int IDLE_THRESHOLD = 50;

    // Cycles to wait for the first byte to appear after packet is sent.
    // Covers fcs_control buffering + MAC lookup + crossbar pipeline.
    localparam int OUTPUT_TIMEOUT = 5000;

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
        $display("[%0t] Sending packet %0d (%0d bytes) on port %0d",
                 $time, pkt_idx, plen, port);

        for (int b = 0; b < plen; b++) begin
            @(negedge i_clk);
            port_rx_ctrl[port] = 1'b1;
            // port_rx_data[port] = packets[pkt_idx][b];
            port_rx_data[port] = {packets[pkt_idx][b][0], packets[pkt_idx][b][1],
                                  packets[pkt_idx][b][2], packets[pkt_idx][b][3],
                                  packets[pkt_idx][b][4], packets[pkt_idx][b][5],
                                  packets[pkt_idx][b][6], packets[pkt_idx][b][7]};
        end

        @(posedge i_clk);
        @(negedge i_clk);
        port_rx_ctrl[port] = 1'b0;
        port_rx_data[port] = 8'b0;
    endtask

    // ----------------------------------------------------------------
    // send_oversized_packet : drives a frame that is a few bytes beyond
    // the 1518-byte limit.  No valid CRC — just raw bytes.
    // ----------------------------------------------------------------
    task automatic send_oversized_packet(int port);
        // 8-byte preamble/SFD
        automatic logic [7:0] preamble [8] = '{8'hAA,8'hAA,8'hAA,8'hAA,
                                               8'hAA,8'hAA,8'hAA,8'hAB};
        // Frame body: 6 DST_MAC + 6 SRC_MAC + 2 EtherType + 1506 payload + 4 dummy FCS
        // = 1524 bytes (6 bytes over the 1518-byte limit)
        localparam int OVERSIZE_BODY = 1524;

        $display("[%0t] Sending OVERSIZED packet on port %0d (frame body = %0d bytes, limit = 1518)",
                 $time, port, OVERSIZE_BODY);

        foreach (preamble[i]) begin
            @(negedge i_clk);
            port_rx_ctrl[port] = 1'b1;
            port_rx_data[port] = preamble[i];
        end

        for (int b = 0; b < OVERSIZE_BODY; b++) begin
            @(negedge i_clk);
            port_rx_ctrl[port] = 1'b1;
            port_rx_data[port] = b[7:0];   // incrementing pattern
        end

        @(posedge i_clk);
        @(negedge i_clk);
        port_rx_ctrl[port] = 1'b0;
        port_rx_data[port] = 8'b0;

        $display("[%0t] Oversized packet done, rx_ctrl dropped", $time);
    endtask

    // ----------------------------------------------------------------
    // check_output : monitors crossbar tx_ctrl / tx_data after a packet
    //   is sent and performs three checks:
    //
    //   Item 2 — report which output ports fired
    //   Item 4 — assert no self-loop (ingress port must not fire)
    //   Item 5 — assert byte count per output port == expected length
    //
    //   ingress_port : 0-3, the port the packet was sent in on
    // ----------------------------------------------------------------
    task automatic check_output(int pkt_idx, int ingress_port);
        int  byte_count[4];
        int  timeout;
        bit  self_loop_fail;
        bit  length_fail[4];
        bit  any_fail;

        foreach (byte_count[p]) byte_count[p] = 0;
        foreach (length_fail[p]) length_fail[p] = 0;
        self_loop_fail = 0;

        // Wait for the first tx_ctrl activity
        timeout = 0;
        @(posedge i_clk);
        while (tx_ctrl == 4'b0) begin
            @(posedge i_clk);
            if (++timeout > OUTPUT_TIMEOUT) begin
                $display("[%0t] PKT%0d TIMEOUT: no crossbar output after %0d cycles",
                         $time, pkt_idx, OUTPUT_TIMEOUT);
                $display("  (check packet.txt has valid FCS bytes)\n");
                return;
            end
        end

        // Count bytes per port until IDLE_THRESHOLD consecutive idle cycles.
        // This handles both unicast (one port fires) and broadcast (several
        // ports fire, potentially at different times via DRR round-robin).
        begin : count_loop
            int idle;
            idle = 0;
            while (idle < IDLE_THRESHOLD) begin
                if (tx_ctrl != 4'b0) begin
                    idle = 0;
                    for (int p = 0; p < 4; p++)
                        if (tx_ctrl[p]) byte_count[p]++;
                end else
                    idle++;
                @(posedge i_clk);
            end
        end

        // ---- Report ----
        $display("\n--- Packet %0d output report (ingress port %0d, expected %0d bytes) ---",
                 pkt_idx, ingress_port, pkt_lens[pkt_idx]);

        for (int p = 0; p < 4; p++) begin
            if (byte_count[p] > 0) begin
                // Item 2: port fired
                $write("  Port %0d fired : %0d bytes", p, byte_count[p]);

                // Item 5: length check
                if (byte_count[p] !== pkt_lens[pkt_idx]) begin
                    length_fail[p] = 1;
                    $display("  [LENGTH FAIL — expected %0d]", pkt_lens[pkt_idx]);
                end else
                    $display("  [LENGTH PASS]");

                // Item 4: self-loop check
                if (p == ingress_port) begin
                    self_loop_fail = 1;
                    $display("  Port %0d : SELF-LOOP FAIL", p);
                end
            end
        end

        // Overall verdict
        any_fail = self_loop_fail;
        for (int p = 0; p < 4; p++) any_fail |= length_fail[p];

        if (!any_fail)
            $display("=== Packet %0d: ALL CHECKS PASSED ===", pkt_idx);
        else
            $display("=== Packet %0d: CHECKS FAILED ===", pkt_idx);

        $display("---\n");
    endtask

    // ----------------------------------------------------------------
    // Main stimulus
    // ----------------------------------------------------------------
    initial begin
        i_reset      = 1'b0;
        port_rx_ctrl = 4'b0;
        foreach (port_rx_data[p]) port_rx_data[p] = 8'b0;

        repeat(4) @(posedge i_clk);
        i_reset = 1'b1;
        repeat(2) @(posedge i_clk);

        read_packet_file(PACKET_FILE);

        // ----------------------------------------------------------------
        // RR arbitration demo: inject packet 0 on all 4 ports at once.
        // With all ingress FIFOs non-empty simultaneously, output_control
        // must choose between competing ports — rr_ptr advances each cycle
        // a new port is granted, making the round-robin visible in waves.
        // ----------------------------------------------------------------
        // if (num_packets >= 1) begin
        //     $display("\n=== RR demo: all 4 ports inject packet 0 concurrently ===");
        //     send_packet(0, 0);
        //     // fork
        //     //     send_packet(0, 0);
        //     //     send_packet(0, 1);
        //     //     send_packet(0, 2);
        //     //     send_packet(0, 3);
        //     // join
        //     // send_packet(1, 0);
        //     repeat(100) @(posedge i_clk);
        //     $display("=== RR demo complete ===\n");
        //     repeat(8) @(posedge i_clk);
        // end
        
        // ----------------------------------------------------------------
        // Oversized packet test: send a frame 6 bytes over the 1518-byte
        // limit, then send a normal packet to verify the switch recovers.
        // ----------------------------------------------------------------
        $display("\n=== Oversized packet test ===");
        send_oversized_packet(0);
        repeat(200) @(posedge i_clk);   // give time for any spurious output
        
        send_packet(0, 0);
            repeat(100) @(posedge i_clk);

            send_oversized_packet(0);
        repeat(200) @(posedge i_clk);   // give time for any spurious output
        
        send_packet(0, 0);
            repeat(2000) @(posedge i_clk);
        // end
        $display("=== Oversized packet test complete ===\n");

        // for (int p = 0; p + 1 < num_packets; p += 2) begin
        //     send_packet(p, 0);
        //     check_output(p, 0);
        //     repeat(4) @(posedge i_clk);

        //     send_packet(p+1, 1);
        //     check_output(p+1, 1);
        //     repeat(4) @(posedge i_clk);
        // end

        // if (num_packets % 2 == 1) begin
        //     send_packet(num_packets - 1, 0);
        //     check_output(num_packets - 1, 0);
        //     repeat(4) @(posedge i_clk);
        // end

        $display("Simulation complete.");
        $stop;
    end

endmodule
