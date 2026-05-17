package switch_pkg;

localparam int PACKET_DUMP_BYTES_PER_LINE = 16;

function automatic void print_timestamped_packet(
    input string title,
    input byte   pkt[$]
);
    int line_start;
    int line_end;

    $display("[%16t] %s (%0d bytes)", $time, title, pkt.size());

    for (line_start = 0; line_start < pkt.size(); line_start += PACKET_DUMP_BYTES_PER_LINE) begin
        line_end = line_start + PACKET_DUMP_BYTES_PER_LINE;
        if (line_end > pkt.size())
            line_end = pkt.size();

        $write("[%16t]   %04x : ", $time, line_start);

        for (int i = line_start; i < line_start + PACKET_DUMP_BYTES_PER_LINE; i++) begin
            if (i < pkt.size())
                $write("%02x ", pkt[i]);
            else
                $write("   ");
        end

        $write(" |");
        for (int i = line_start; i < line_end; i++) begin
            $write(".");
        end
        for (int i = line_end; i < line_start + PACKET_DUMP_BYTES_PER_LINE; i++)
            $write(" ");
        $display("|");
    end
endfunction

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

        $display("[%16t] FRAME: created src=%h dst=%h in_port=%0d",
                $time, src_mac, dst_mac, src_port);
    endfunction

    // Standard Ethernet CRC32: poly=0x04C11DB7, init=0xFFFFFFFF, RefIn=true,
    // RefOut=true, XorOut=0xFFFFFFFF. Reflected polynomial 0xEDB88320 handles
    // RefIn/RefOut implicitly. Verified: FCS of the ping packet = 0xD059FF9B.
    function automatic bit [31:0] eth_crc32(byte data[$]);
        bit [31:0] crc = 32'hFFFFFFFF;
        foreach (data[i]) begin
            bit [7:0] d = data[i];
            for (int b = 0; b < 8; b++) begin
                bit fb = crc[0] ^ d[0];
                crc = {1'b0, crc[31:1]};
                if (fb) crc ^= 32'hEDB88320;
                d = {1'b0, d[7:1]};
            end
        end
        return ~crc;
    endfunction

    // build Ethernet frame: [PREAMBLE(7)][SFD(1)][DST(6)][SRC(6)][TYPE(2)][PAYLOAD][FCS(4)]
    // FCS = standard CRC32 over [DST][SRC][TYPE][PAYLOAD], appended little-endian (LSB first).
    function void build(int payload_len = 1500);

        byte frame_data[$];
        bit [31:0] fcs;

        $display("[%16t] FRAME: building packet...", $time);

        data.delete();

        // PREAMBLE: 7 × 0xAA
        for (int i = 0; i < 7; i++)
            data.push_back(8'hAA);

        // SFD: 0xAB
        data.push_back(8'hAB);

        // DST MAC (big-endian)
        for (int i = 5; i >= 0; i--)
            frame_data.push_back(dst_mac >> (i*8));

        // SRC MAC (big-endian)
        for (int i = 5; i >= 0; i--)
            frame_data.push_back(src_mac >> (i*8));

        // EtherType
        frame_data.push_back(8'h08);
        frame_data.push_back(8'h00);

        // Payload
        for (int i = 0; i < payload_len; i++)
            frame_data.push_back(i);

        fcs = eth_crc32(frame_data);

        // $display("  FCS = %08x", fcs);

        foreach (frame_data[i])
            data.push_back(frame_data[i]);

        // FCS appended little-endian (LSB first), matching standard Ethernet
        for (int i = 0; i < 4; i++)
            data.push_back(fcs >> (i*8));

        $display("[%16t] FRAME: build complete, size=%0d", $time, data.size());
        print_timestamped_packet("[FRAME] Full packet", data);

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

    // internal queues
    mailbox #(frame) drv_port_q[PORTS];

    function new(
        virtual switch_if vif,
        mailbox #(frame) exp_q[PORTS]
    );
        this.vif   = vif;
        this.exp_q = exp_q;
        foreach (drv_port_q[i]) drv_port_q[i] = new();

        $display("[%16t] DRV: constructed", $time);
    endfunction

    ////////////////// RESET //////////////////

    task reset();
        $display("[%16t] DRV: reset start", $time);

        vif.reset <= 0;
        vif.cb.rx_ctrl <= '0;
        vif.cb.rx_data <= '0;

        repeat (5) @(vif.cb);

        vif.reset <= 1;

        repeat (5) @(vif.cb);

        $display("[%16t] DRV: reset done", $time);
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

    task drive_physical_pins(frame f);
        int p = f.src_port;
        vif.cb.rx_ctrl[p] <= 0;
        @(vif.cb);
        foreach (f.data[i]) begin
            vif.cb.rx_ctrl[p] <= 1;
            vif.cb.rx_data[p*DATA_W +: DATA_W] <= f.data[i];
            @(vif.cb);
        end
        vif.cb.rx_ctrl[p] <= 0;
        repeat (12) @(vif.cb);
    endtask

    // Use for TC1-TC9. It waits for the frame to finish.
    task send_frame(frame f);
        f.dst_port = compute_expected(f);
        foreach (exp_q[p]) if (f.dst_port[p]) exp_q[p].put(copy_frame(f));
        
        drive_physical_pins(f); // This blocks the testcase until done
    endtask

    // Use for Stress Testing. It returns in 0 time.
    task queue_frame(frame f);
        f.dst_port = compute_expected(f);
        foreach (exp_q[p]) if (f.dst_port[p]) exp_q[p].put(copy_frame(f));
        
        drv_port_q[f.src_port].put(f); // drop in the mailbox
    endtask

    ////////////////// SIMPLE GENERATOR //////////////////

    task send_simple_frame(
        int src_port,
        bit [47:0] src_mac,
        bit [47:0] dst_mac
    );

        frame f = new(src_mac, dst_mac, src_port);
        f.build(46); // Default to minimum size for "simple" frames
        send_frame(f);

    endtask

    task send_corrupted_frame(frame f);
        int port = f.src_port;
        int last_idx;

        // corrupt by flipping last fcs byte
        last_idx = f.data.size() - 1;
        f.data[last_idx] = ~f.data[last_idx];

        $display("[%16t] DRV: sending CORRUPTED frame from port %0d (FCS byte %0d flipped to %02x)",
             $time, port, last_idx, f.data[last_idx]);

        vif.cb.rx_ctrl[port] <= 0;
        @(vif.cb);

        foreach (f.data[i]) begin
            vif.cb.rx_ctrl[port] <= 1;
            vif.cb.rx_data[port*DATA_W +: DATA_W] <= f.data[i];
            @(vif.cb);
        end

        vif.cb.rx_ctrl[port] <= 0;
        repeat (12) @(vif.cb);

    endtask

////////////////// BACKGROUND MONITOR //////////////////
    task run();
        for (int i = 0; i < PORTS; i++) begin
            automatic int port_idx = i; // Create a local copy for the thread
            fork
                forever begin
                    frame f;
                    drv_port_q[port_idx].get(f); // Wait for something to arrive
                    drive_physical_pins(f);      // driver timezz
                end
            join_none
        end
    endtask
    
    // 
    task wait_all_done();
        for (int i = 0; i < PORTS; i++) begin
            wait(drv_port_q[i].num() == 0);
        end
        repeat(50) @(vif.cb); // drain time
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

        // skip 8 bytes (7 Preamble + 1 SFD)
        for (int i = 8; i < 14; i++)
            f.dst_mac = (f.dst_mac << 8) | f.data[i];

        for (int i = 14; i < 20; i++)
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

                    print_timestamped_packet(
                        $sformatf("[TX] Packet received @ port %0d, dst=%012h, src=%012h",
                                  p, pkt[p].dst_mac, pkt[p].src_mac),
                        pkt[p].data
                    );

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
    string current_tc = "NO_TC";
    int tc_start_error_count = 0;
    int tc_start_compare_count = 0;
    string suite_failed_tcs[$];
    string suite_seen_tcs[$];

    // searchable list
    frame exp_list[PORTS][$];

    function new(
        virtual switch_if vif,
        mailbox #(frame) exp_q[PORTS],
        mailbox #(frame) act_q[PORTS]
    );
        this.vif   = vif;
        this.exp_q = exp_q;
        this.act_q = act_q;
    endfunction

    task start_tc(string tc_name);
        current_tc = tc_name;
        tc_start_error_count = error_count;
        tc_start_compare_count = compare_count;
        $display("[%16t] [SB] ---- %s START ----", $time, current_tc);
    endtask


    task run();
        frame exp_pkt, act_pkt, f;
        int p, i, d_idx, match_idx;
        bit found;

        forever begin
            @(vif.cb);

            for (p = 0; p < PORTS; p++) begin
                // 1. move the 'expected' mailbox into searchable list
                while (exp_q[p].num() > 0) begin
                    exp_q[p].get(f);
                    exp_list[p].push_back(f);
                end

                // 2. check the 'actual' Mailbox for frames coming out of the hardware
                while (act_q[p].num() > 0) begin
                    act_q[p].get(act_pkt);

                    // the monitor just saw bits; we need to turn them into MAC addresses
                    decode_mac_from_raw(act_pkt); 

                    found = 0;
                    match_idx = -1;

                    // 3. find the oldest packet in the pool that matches this source
                    for (i = 0; i < exp_list[p].size(); i++) begin
                        if (exp_list[p][i].src_mac == act_pkt.src_mac) begin
                            match_idx = i;
                            found = 1;
                            break; 
                        end
                    end

                    if (found) begin
                        exp_pkt = exp_list[p][match_idx];
                        exp_list[p].delete(match_idx); // remove it so we don't match it again
                        compare_frames(exp_pkt, act_pkt, p);
                    end else begin
                        $error("[%16t] [SB] Port %0d: Unexpected packet! Source MAC %h not found in expected pool", 
                               $time, p, act_pkt.src_mac);
                        print_timestamped_packet("[SB] Unexpected packet", act_pkt.data);
                        error_count++;
                    end
                end
            end
        end
    endtask

    // helper task to conv the raw data into MAC 
    task decode_mac_from_raw(frame f);
        f.src_mac = 0;
        f.dst_mac = 0;
        // dst_mac is bytes 8-13, src_mac is bytes 14-19
        for (int i=8; i<=13; i++) f.dst_mac = (f.dst_mac << 8) | f.data[i];
        for (int i=14; i<=19; i++) f.src_mac = (f.src_mac << 8) | f.data[i];
    endtask

    task compare_frames(frame exp, frame act, int port);
        compare_count++;
        if (exp.data.size() != act.data.size()) begin
            $error("[%16t] [SB] Port %0d: Size mismatch! Exp:%0d Act:%0d",
                   $time, port, exp.data.size(), act.data.size());
            print_timestamped_packet("[SB] Expected packet", exp.data);
            print_timestamped_packet("[SB] Actual packet", act.data);
            error_count++;
            return;
        end

        foreach (exp.data[i]) begin
            if (exp.data[i] !== act.data[i]) begin
                $error("[%16t] [SB] Port %0d: Data mismatch at byte %0d! Exp:%02h Act:%02h",
                       $time, port, i, exp.data[i], act.data[i]);
                print_timestamped_packet("[SB] Expected packet", exp.data);
                print_timestamped_packet("[SB] Actual packet", act.data);
                error_count++;
                break;
            end
        end

    endtask


    ////////////////// FINAL REPORT //////////////////

    task report(string tc_name);
        int tc_errors;
        int tc_checks;

        // small drain time to finish comparisons
        repeat (10) @(vif.cb);

        tc_errors = error_count - tc_start_error_count;
        tc_checks = compare_count - tc_start_compare_count;

        if (tc_errors == 0)
            $display("[%16t] [SB] %s : PASS (%0d checks) ", $time, tc_name, tc_checks);
        else begin
            $display("[%16t] [SB] %s : FAIL (%0d errors, %0d checks)",
                     $time, tc_name, tc_errors, tc_checks);
            suite_failed_tcs.push_back(tc_name);
        end

        suite_seen_tcs.push_back(tc_name);

    endtask

    task suite_report();
        $display("[%16t] [SB] ================================", $time);
        if (suite_failed_tcs.size() == 0) begin
            $display("[%16t] [SB] ALL TESTS PASS (%0d tests)", $time, suite_seen_tcs.size());
        end else begin
            $display("[%16t] [SB] The following tests failed:", $time);
            foreach (suite_failed_tcs[i])
                $display("[%16t] [SB] %s: FAIL", $time, suite_failed_tcs[i]);
        end
        $display("[%16t] [SB] ================================", $time);
    endtask

endclass
endpackage
