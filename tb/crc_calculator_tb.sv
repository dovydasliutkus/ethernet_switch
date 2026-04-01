`timescale 1ns/1ps

// =============================================================================
// Testbench for crc_calculator (parallel GMII-style interface)
//
// Ethernet frame layout expected in packet file (bytes in hex, "---" separates):
//   [0..5]  dst_mac   [6..11] src_mac   [12..13] EtherType/Length
//   [14..14+len-1] payload   [last 4] FCS
// =============================================================================

module crc_calculator_tb;

    logic        clk, reset;
    logic        i_rx_ctrl;
    logic [7:0]  i_data;
    logic [47:0] dst_mac, src_mac;
    logic [10:0] o_packet_length;
    logic        o_valid;

    // FIFO read interface
    logic        i_length_ren, i_status_ren;
    logic        o_length_empty, o_status_empty;

    parameter packet_file_path = "E:/UserData/Desktop/Term2/fpga_for_comms/eth_switch/tb/packet.txt";

    crc_calculator dut (
        .clk             (clk),
        .reset           (reset),
        .i_rx_ctrl       (i_rx_ctrl),
        .i_data          (i_data),
        .dst_mac         (dst_mac),
        .src_mac         (src_mac),
        .o_packet_length (o_packet_length),
        .o_valid         (o_valid),
        .i_length_ren    (i_length_ren),
        .i_status_ren    (i_status_ren),
        .o_length_empty  (o_length_empty),
        .o_status_empty  (o_status_empty)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    localparam MAX_BYTES   = 1600;
    localparam MAX_PACKETS = 32;

    logic [7:0]  packets    [MAX_PACKETS][MAX_BYTES];
    int          pkt_lens   [MAX_PACKETS];
    int          num_packets;

    // Values read back from FIFOs after each packet
    logic        captured_valid;
    logic [10:0] captured_packet_length;

// --------------------------------------------------------
// read_packet_file : parse hex bytes from file, "---" separates packets
    task automatic read_packet_file(input string filename);
        int fd;
        string token;
        int byte_val;
        int pkt_idx, byte_idx;

        fd = $fopen(filename, "r");
        if (fd == 0) $fatal(1, "Cannot open: %s", filename);

        pkt_idx = 0; byte_idx = 0; num_packets = 0;

        while ($fscanf(fd, " %s", token) == 1) begin
            if (token == "---") begin
                pkt_lens[pkt_idx] = byte_idx;
                $display("Packet %0d: %0d bytes", pkt_idx, byte_idx);
                pkt_idx++;
                byte_idx = 0;
            end else begin
                if ($sscanf(token, "%h", byte_val) == 1)
                    packets[pkt_idx][byte_idx++] = byte_val[7:0];
                else
                    $fatal(1, "Unexpected token: %s", token);
            end
        end

        if (byte_idx > 0) begin
            pkt_lens[pkt_idx] = byte_idx;
            $display("Packet %0d: %0d bytes", pkt_idx, byte_idx);
            pkt_idx++;
        end

        num_packets = pkt_idx;
        $display("Total packets loaded: %0d", num_packets);
        $fclose(fd);
    endtask

// --------------------------------------------------------
// send_packet : drives i_rx_ctrl + i_data for the full frame.
//   i_rx_ctrl mirrors gmii_rx_dv: high for every byte, goes low after last byte.
//   The DUT writes both FIFOs on the posedge after i_rx_ctrl drops.
    task automatic send_packet(int pkt_idx);
        int plen = pkt_lens[pkt_idx];
        $display("\nSending packet %0d (%0d bytes)...", pkt_idx, plen);

        for (int i = 0; i < plen; i++) begin
            @(negedge clk);
            i_rx_ctrl = 1'b1;
            i_data    = packets[pkt_idx][i];
        end

        // Wait for last byte to be registered into rem_reg
        @(posedge clk);

        // Deassert i_rx_ctrl — DUT PAYLOAD else branch fires next posedge, writing FIFOs
        @(negedge clk);
        i_rx_ctrl = 1'b0;
        i_data    = 8'h00;
    endtask

// --------------------------------------------------------
// read_fifo_outputs : waits until both FIFOs are non-empty, then reads one entry.
//   Altera sync FIFOs: rdreq on posedge N → data valid on posedge N+1.
    task automatic read_fifo_outputs();
        // Wait for DUT to finish writing (FIFOs take 1 cycle after wrreq to update empty)
        @(posedge clk);

        // Poll until both FIFOs have data (timeout after 20 cycles)
        begin : wait_loop
            int timeout = 0;
            while (o_length_empty || o_status_empty) begin
                @(posedge clk);
                timeout++;
                if (timeout > 20) begin
                    $display("  TIMEOUT waiting for FIFOs to be non-empty");
                    disable wait_loop;
                end
            end
        end

        // Pulse read enables for one cycle
        @(negedge clk);
        i_length_ren = 1'b1;
        i_status_ren = 1'b1;

        // Data appears at q on the next posedge
        @(posedge clk);
        @(negedge clk);
        i_length_ren = 1'b0;
        i_status_ren = 1'b0;
        #1; // let outputs settle

        captured_packet_length = o_packet_length;
        captured_valid         = o_valid;

        // Return to IDLE before next packet
        repeat(2) @(posedge clk);
    endtask

// --------------------------------------------------------
// check_packet : computes expected values and compares to captured outputs.
    task automatic check_packet(int pkt_idx);
        logic [47:0] exp_dst_mac, exp_src_mac;
        logic [10:0] exp_o_packet_length;
        int          pass;
        pass = 1;

        // --- dst_mac ---
        // DUT stores bytes 0-3 inverted (CRC preconditioning), bytes 4-5 as-is
        exp_dst_mac[ 7: 0] = ~packets[pkt_idx][0];
        exp_dst_mac[15: 8] = ~packets[pkt_idx][1];
        exp_dst_mac[23:16] = ~packets[pkt_idx][2];
        exp_dst_mac[31:24] = ~packets[pkt_idx][3];
        exp_dst_mac[39:32] =  packets[pkt_idx][4];
        exp_dst_mac[47:40] =  packets[pkt_idx][5];

        // --- src_mac ---
        // Bytes 6-11, not inverted
        exp_src_mac[ 7: 0] =  packets[pkt_idx][ 6];
        exp_src_mac[15: 8] =  packets[pkt_idx][ 7];
        exp_src_mac[23:16] =  packets[pkt_idx][ 8];
        exp_src_mac[31:24] =  packets[pkt_idx][ 9];
        exp_src_mac[39:32] =  packets[pkt_idx][10];
        exp_src_mac[47:40] =  packets[pkt_idx][11];

        // --- o_packet_length ---
        // DUT writes counter (total bytes received) into length FIFO at end of frame
        exp_o_packet_length = 11'(pkt_lens[pkt_idx]);

        // --- Checks ---
        if (captured_valid !== 1'b1) begin
            $display("  FAIL o_valid       : got %b, expected 1 (CRC OK)", captured_valid);
            pass = 0;
        end else
            $display("  PASS o_valid       : 1 (CRC OK)");

        if (dst_mac !== exp_dst_mac) begin
            $display("  FAIL dst_mac       : got %h, expected %h", dst_mac, exp_dst_mac);
            pass = 0;
        end else
            $display("  PASS dst_mac       : %h", dst_mac);

        if (src_mac !== exp_src_mac) begin
            $display("  FAIL src_mac       : got %h, expected %h", src_mac, exp_src_mac);
            pass = 0;
        end else
            $display("  PASS src_mac       : %h", src_mac);

        if (captured_packet_length !== exp_o_packet_length) begin
            $display("  FAIL pkt_length    : got %0d, expected %0d", captured_packet_length, exp_o_packet_length);
            pass = 0;
        end else
            $display("  PASS pkt_length    : %0d", captured_packet_length);

        if (pass)
            $display("=== Packet %0d: ALL CHECKS PASSED ===", pkt_idx);
        else
            $display("=== Packet %0d: CHECKS FAILED ===", pkt_idx);
    endtask

// --------------------------------------------------------
    initial begin
        reset        = 1;
        i_rx_ctrl    = 0;
        i_data       = 0;
        i_length_ren = 0;
        i_status_ren = 0;

        repeat(4) @(posedge clk);
        reset = 0;
        repeat(2) @(posedge clk);

        read_packet_file(packet_file_path);

        for (int p = 0; p < num_packets; p++) begin
            send_packet(p);
            read_fifo_outputs();
            check_packet(p);
        end

        $display("\nSimulation complete.");
        $stop;
    end

endmodule
