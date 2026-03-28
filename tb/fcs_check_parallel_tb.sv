`timescale 1ns/1ps

module fcs_check_parallel_tb;

    logic clk, reset;
    logic start_of_frame, end_of_frame;
    logic [7:0] data_in;
    logic fcs_error;

    fcs_check_parallel dut (
        .clk            (clk),
        .reset          (reset),
        .start_of_frame (start_of_frame),
        .end_of_frame   (end_of_frame),
        .data_in        (data_in),
        .fcs_error      (fcs_error)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    localparam MAX_BYTES    = 256;   // max bytes per packet
    localparam MAX_PACKETS  = 32;

    logic [7:0] packets    [MAX_PACKETS][MAX_BYTES];
    int         pkt_lens   [MAX_PACKETS]; // in bytes
    int         num_packets;

// --------------------------------------------------------
// read_packet_file : parse packets (bytes) from file, "---" separates packets
    task automatic read_packet_file(input string filename);
        int fd;
        string token;
        int byte_val;
        int pkt_idx, byte_idx;

        fd = $fopen(filename, "r");
        if (fd == 0) $fatal(1, "Cannot open: %s", filename);

        pkt_idx   = 0;
        byte_idx  = 0;
        num_packets = 0;

        while ($fscanf(fd, " %s", token) == 1) begin
            if (token == "---") begin
                pkt_lens[pkt_idx] = byte_idx;
                $display("Packet %0d: %0d bytes", pkt_idx, byte_idx);
                pkt_idx++;
                byte_idx = 0;
            end else begin
                if ($sscanf(token, "%h", byte_val) == 1) begin
                    packets[pkt_idx][byte_idx++] = byte_val[7:0];
                end else begin
                    $fatal(1, "Unexpected token: %s", token);
                end
            end
        end

        // Flush last packet if no trailing ---
        if (byte_idx > 0) begin
            pkt_lens[pkt_idx] = byte_idx;
            $display("Packet %0d: %0d bytes", pkt_idx, byte_idx);
            pkt_idx++;
        end

        num_packets = pkt_idx;
        $display("Total packets: %0d", num_packets);
        $fclose(fd);
    endtask

// --------------------------------------------------------
    task automatic send_packet(int pkt_idx);
        int plen = pkt_lens[pkt_idx];
        $display("Sending packet %0d (%0d bytes)...", pkt_idx, plen);

        for (int i = 0; i < plen; i++) begin
            @(negedge clk);
            start_of_frame = (i == 0);
            end_of_frame   = (i == plen - 4);
            data_in        = packets[pkt_idx][i];
        end

        @(negedge clk);
        start_of_frame = 0; end_of_frame = 0; data_in = 0;

        // Let result settle
        repeat(4) @(posedge clk);
        $display("Packet %0d -> fcs_error = %b (expect 0)", pkt_idx, fcs_error);
    endtask

// --------------------------------------------------------
    initial begin
        reset = 1;
        start_of_frame = 0; end_of_frame = 0; data_in = 0;

        repeat(4) @(posedge clk);
        reset = 0;
        repeat(2) @(posedge clk);

        read_packet_file("E:/UserData/Desktop/Term2/fpga_for_comms/ex_CRC/packet.txt");

        for (int p = 0; p < num_packets; p++) begin
            send_packet(p);
        end

        $stop;
    end

endmodule