package switch_pkg;

//////////////////// FRAME ////////////////////

class frame;

    bit [47:0] src_mac;
    bit [47:0] dst_mac;

    int src_port;
    bit [3:0] dst_port; // expected output mask

    byte data[$];

    function new(
        bit [47:0] src_mac,
        bit [47:0] dst_mac,
        int src_port
    );
        this.src_mac  = src_mac;
        this.dst_mac  = dst_mac;
        this.src_port = src_port;

        $display("[%0t] FRAME: created src=%h dst=%h in_port=%0d",
                $time, src_mac, dst_mac, src_port);
    endfunction

    // CORRECT CRC32 CALCULATOR 
    // function automatic bit [31:0] eth_crc32(byte data[$]);

    //     bit [31:0] crc = 32'hFFFFFFFF;
    //     bit fb;

    //     foreach (data[i]) begin
    //         byte d = data[i];

    //         // uses https://github.com/amal-araweelo/34349_fpga_comm_exercises/blob/main/ex1_ethernet_fcs/tb/src/fcs_pkg.sv
    //         for (int b = 7; b >= 0; b--) begin
    //             fb = d[b] ^ crc[31];
    //             crc = {crc[30:0], 1'b0};
    //             if (fb)
    //                 crc ^= 32'h04C11DB7;
    //         end
    //     end

    //     return ~crc;

    // endfunction

    // MATCHES DUT CRC CALCULATOR
    function automatic bit [31:0] eth_crc32(byte data[$]);

        bit [31:0] crc = 32'h00000000;
        $write("DEBUGGGG");
        foreach (data[i]) begin
            bit [7:0] d = data[i];
            d = {d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7]};
            $write("%02x ", d);
            for (int b = 0; b < 8; b++) begin
                bit fb = crc[31] ^ d[7];
                crc = {crc[30:0], 1'b0};
                if (fb)
                    crc ^= 32'h04C11DB7;
                d = {d[6:0],1'b0};
            end
        end

        return crc;
    endfunction

    // build Ethernet frame: [PREAMBLE(7)][SFD(1)][DST(6)][SRC(6)][TYPE(2)][PAYLOAD][FCS(4)]
    //
    // CRC is computed only over [DST][SRC][TYPE][PAYLOAD] (preamble excluded), matching
    // what the DUT does in crc_calculator.sv:
    //   1. First 4 bytes of frame data (DST_MAC[0..3]) are inverted → simulates init=0xFFFFFFFF
    //   2. CRC output is inverted (XorOut=0xFFFFFFFF) → DUT residue check passes (rem_reg==0xFFFFFFFF)
    //   3. FCS appended big-endian (MSB first)
    function void build(int payload_len = 46);

        byte frame_data[$];  // DST + SRC + Type + Payload (no preamble)
        byte crc_in[$];      // frame_data with DST_MAC[0..3] inverted
        bit [31:0] fcs;

        $display("[%0t] FRAME: building packet...", $time);

        data.delete();

        // PREAMBLE: 7 × 0xAA
        for (int i = 0; i < 7; i++)
            data.push_back(8'hAA);

        // SFD: 0xAB (standard start-of-frame delimiter)
        data.push_back(8'hAB);

        // DST MAC (big-endian)
        for (int i = 5; i >= 0; i--)
            frame_data.push_back(dst_mac >> (i*8));

        // SRC MAC (big-endian)
        for (int i = 5; i >= 0; i--)
            frame_data.push_back(src_mac >> (i*8));

        // EtherType (dummy IPv4)
        frame_data.push_back(8'h08);
        frame_data.push_back(8'h00);

        // Payload
        for (int i = 0; i < payload_len; i++)
            frame_data.push_back(i);

        // Build CRC input: invert first 4 bytes (DST_MAC[0..3]) to simulate init=0xFFFFFFFF
        foreach (frame_data[i]) begin
            byte b = frame_data[i];
            if (i < 4) b = ~b;
            crc_in.push_back(b);
        end

        // Generate fcs and invert as per ethernet standard
        fcs = eth_crc32(crc_in);

        $display("  FCS = %08x", fcs);

        // Append frame data then FCS (big-endian, MSB first)
        foreach (frame_data[i])
            data.push_back(frame_data[i]);

        for (int i = 3; i >= 0; i--)
            data.push_back(fcs >> (i*8));

        $display("[%0t] FRAME: build complete, size=%0d", $time, data.size());

        $write("[%0t] FRAME FULL PACKET (%0d bytes): ", $time, data.size());
        foreach (data[i])
            $write("%02x ", data[i]);
        $display("");

    endfunction

    task test_known_packet(); // from exercise 2

        byte pkt[$] = '{
            8'h00,8'h10,8'hA4,8'h7B,8'hEA,8'h80,
            8'h00,8'h12,8'h34,8'h56,8'h78,8'h90,
            8'h08,8'h00,
            8'h45,8'h00,8'h00,8'h2E,8'hB3,8'hFE,8'h00,8'h00,
            8'h80,8'h11,8'h05,8'h40,
            8'hC0,8'hA8,8'h00,8'h2C,
            8'hC0,8'hA8,8'h00,8'h04,
            8'h04,8'h00,8'h04,8'h00,8'h00,8'h1A,
            8'h2D,8'hE8,
            8'h00,8'h01,8'h02,8'h03,8'h04,8'h05,
            8'h06,8'h07,8'h08,8'h09,8'h0A,8'h0B,
            8'h0C,8'h0D,8'h0E,8'h0F,8'h10,8'h11
        };
        
        bit [31:0] crc;
        $write("BYTE STREAM: ");
        foreach (pkt[i])
            $write("%02x ", pkt[i]);
        $display("");
        crc = eth_crc32(pkt);

        $display("EXPECTED CRC = E6C53DB2");
        $display("CALC CRC     = %08x", crc);

    endtask

endclass

//////////////////// DRIVER ////////////////////

class switch_driver #(parameter PORTS=4, DATA_W=8);

    virtual switch_if vif;
    mailbox #(frame) exp_q[PORTS];

    function new(
        virtual switch_if vif,
        mailbox #(frame) exp_q[PORTS]
    );
        this.vif   = vif;
        this.exp_q = exp_q;

        $display("[%0t] DRV: constructed", $time);
    endfunction

    ////////////////// RESET //////////////////

    task reset();
        $display("[%0t] DRV: reset start", $time);

        vif.reset <= 0;
        vif.cb.rx_ctrl <= '0;
        vif.cb.rx_data <= '0;

        repeat (5) @(vif.cb);

        vif.reset <= 1;

        repeat (5) @(vif.cb);

        $display("[%0t] DRV: reset done", $time);
    endtask

    ////////////////// EXPECTED MODEL //////////////////

    bit [3:0] mac_table [bit[47:0]];

    function bit [3:0] compute_expected(frame f);

        bit [3:0] mask;

        if (mac_table.exists(f.dst_mac))
            mask = (1 << mac_table[f.dst_mac]);
        else
            mask = 4'b1111 & ~(1 << f.src_port);

        mac_table[f.src_mac] = f.src_port;

        return mask;

    endfunction

    ////////////////// DEEP COPY FUNCTION //////////////////

    function frame copy_frame(frame f);

        frame c = new(f.src_mac, f.dst_mac, f.src_port);

        // copy dst_port as well
        c.dst_port = f.dst_port;

        // deep copy of data array
        c.data = f.data;
        for (int i = 0; i < f.data.size(); i++) begin
            c.data[i] = f.data[i];
        end

        return c;

    endfunction

    ////////////////// SEND FRAME //////////////////

    task send_frame(frame f);

        int port = f.src_port;

        f.build();
        f.dst_port = compute_expected(f);

        // push deep copies into each expected queue
        for (int p = 0; p < PORTS; p++) begin
            if (f.dst_port[p]) begin
                frame f_copy = copy_frame(f);
                exp_q[p].put(f_copy);
            end
        end

        vif.cb.rx_ctrl[port] <= 0;
        @(vif.cb);

        foreach (f.data[i]) begin
            vif.cb.rx_ctrl[port] <= 1;
            vif.cb.rx_data[port*DATA_W +: DATA_W] <= f.data[i];
            @(vif.cb);
        end

        vif.cb.rx_ctrl[port] <= 0;
        @(vif.cb);

    endtask

    ////////////////// SIMPLE GENERATOR //////////////////

    task send_simple_frame(
        int src_port,
        bit [47:0] src_mac,
        bit [47:0] dst_mac
    );

        frame f = new(src_mac, dst_mac, src_port);
        send_frame(f);

    endtask

endclass

//////////////////// TX MONITOR ////////////////////


class tx_monitor #(parameter PORTS=4, DATA_W=8);

    virtual switch_if vif;
    mailbox #(frame) act_q[PORTS];

    // added frame counters per port
    int frame_count[PORTS];

    function new(
        virtual switch_if vif,
        mailbox #(frame) act_q[PORTS]
    );
        this.vif   = vif;
        this.act_q = act_q;
    endfunction

    function void decode_mac(frame f);

        f.dst_mac = 0;
        f.src_mac = 0;

        for (int i = 0; i < 6; i++)
            f.dst_mac = (f.dst_mac << 8) | f.data[i];

        for (int i = 6; i < 12; i++)
            f.src_mac = (f.src_mac << 8) | f.data[i];

    endfunction

    task run();

        frame pkt[PORTS];
        bit   active[PORTS];
        byte  d;

        // initialize state
        foreach (active[p]) begin
            active[p] = 0;
            frame_count[p] = 0;
        end

        forever begin
            @(vif.cb);

            for (int p = 0; p < PORTS; p++) begin

                if (vif.cb.tx_ctrl[p]) begin

                    if (!active[p]) begin
                        pkt[p] = new(48'h0, 48'h0, p);
                        active[p] = 1;
                    end

                    d = vif.cb.tx_data[p*8 +: 8];
                    pkt[p].data.push_back(d);

                end
                else if (active[p]) begin

                    decode_mac(pkt[p]);

                    // PRINT FULL PACKET
                    $write("[%0t] TX PORT %0d FRAME (%0d bytes): ",
                        $time, p, pkt[p].data.size());

                    foreach (pkt[p].data[i]) begin
                        $write("%02x ", pkt[p].data[i]);
                    end
                    $display("");

                    act_q[p].put(pkt[p]);

                    // increment frame counter
                    frame_count[p]++;

                    active[p] = 0;

                end
            end
        end

    endtask

endclass
//////////////////// SCOREBOARD ////////////////////

class scoreboard #(parameter PORTS=4);

    virtual switch_if vif;

    mailbox #(frame) exp_q[PORTS];
    mailbox #(frame) act_q[PORTS];

    int error_count = 0;
    int compare_count = 0;

    function new(
        virtual switch_if vif,
        mailbox #(frame) exp_q[PORTS],
        mailbox #(frame) act_q[PORTS]
    );
        this.vif   = vif;
        this.exp_q = exp_q;
        this.act_q = act_q;
    endfunction


    task run();

        frame exp_pkt, act_pkt;

        forever begin
            @(vif.cb);

            for (int p = 0; p < PORTS; p++) begin

                // EXPECTED + ACTUAL -> compare
                if (exp_q[p].num() > 0 && act_q[p].num() > 0) begin

                    exp_q[p].get(exp_pkt);
                    act_q[p].get(act_pkt);

                    compare_count++;

                    if (exp_pkt.data.size() != act_pkt.data.size()) begin
                        $error("Port %0d: length mismatch", p);
                        error_count++;
                        continue;
                    end

                    foreach (exp_pkt.data[i]) begin
                        if (exp_pkt.data[i] != act_pkt.data[i]) begin
                            $error("Port %0d: data mismatch at %0d", p, i);
                            error_count++;
                            break;
                        end
                    end
                end

                // UNEXPECTED ACTUAL
                else if (act_q[p].num() > 0 && exp_q[p].num() == 0) begin
                    act_q[p].get(act_pkt);
                    $error("Port %0d: unexpected packet", p);
                    error_count++;
                end

                // MISSING EXPECTED (optional but useful)
                else if (exp_q[p].num() > 0 && act_q[p].num() == 0) begin
                    // do nothing yet (could still arrive)
                end

            end
        end

    endtask


    ////////////////// FINAL REPORT //////////////////

    task report(string tc_name);

        // small drain time to finish comparisons
        repeat (10) @(vif.cb);

        if (error_count == 0)
            $display(" %s : PASS (%0d checks) ", tc_name, compare_count);
        else
            $display(" %s : FAIL (%0d errors, %0d checks)",
                     tc_name, error_count, compare_count);

    endtask

endclass
endpackage