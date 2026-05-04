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

    // CRC32 
    function automatic bit [31:0] eth_crc32(byte data[$]);

        bit [31:0] crc = 32'hFFFFFFFF;
        bit fb;

        foreach (data[i]) begin
            byte d = data[i];

            // uses https://github.com/amal-araweelo/34349_fpga_comm_exercises/blob/main/ex1_ethernet_fcs/tb/src/fcs_pkg.sv
            for (int b = 7; b >= 0; b--) begin
                fb = d[b] ^ crc[31];
                crc = {crc[30:0], 1'b0};
                if (fb)
                    crc ^= 32'h04C11DB7;
            end
        end

        return ~crc;

    endfunction

    // Build Ethernet-like frame: [DST][SRC][TYPE][PAYLOAD][FCS]
    function void build(int payload_len = 46);

        byte proc[$];
        bit [31:0] fcs;

        $display("[%0t] FRAME: building packet...", $time);

        data.delete();

        // DST MAC
        for (int i = 5; i >= 0; i--) begin
            byte b = dst_mac >> (i*8);
            data.push_back(b);
            $display("  DST byte[%0d] = %02x", 5-i, b);
        end

        // SRC MAC
        for (int i = 5; i >= 0; i--) begin
            byte b = src_mac >> (i*8);
            data.push_back(b);
            $display("  SRC byte[%0d] = %02x", 5-i, b);
        end

        // EtherType (dummy)
        data.push_back(8'h08);
        data.push_back(8'h00);

        $display("  TYPE = 0800");

        // Payload
        for (int i = 0; i < payload_len; i++) begin
            data.push_back(i);
        end

        // FIX: Match  CRC calculator preprocessing (invert first 4 bytes)
        foreach (data[i]) begin
            byte b = data[i];
            if (i < 4)
                b = ~b;
            proc.push_back(b);
        end

        fcs = eth_crc32(proc);

        $display("  FCS = %08x", fcs);

        // append LSB-first
        for (int i = 3; i >= 0; i--) begin
            byte b = fcs >> (i*8);
            data.push_back(b);
            $display("  FCS byte[%0d] = %02x", i, b);
        end

        $display("[%0t] FRAME: build complete, size=%0d",
                $time, data.size());

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

    ////////////////// SEND FRAME //////////////////

    task send_frame(frame f);

        int port = f.src_port;

        f.build();
        f.dst_port = compute_expected(f);

        for (int p = 0; p < PORTS; p++)
            if (f.dst_port[p])
                exp_q[p].put(f);

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

        foreach (active[p]) active[p] = 0;

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
                    act_q[p].put(pkt[p]);
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

                if (exp_q[p].num() > 0 && act_q[p].num() > 0) begin

                    exp_q[p].get(exp_pkt);
                    act_q[p].get(act_pkt);

                    if (exp_pkt.data.size() != act_pkt.data.size()) begin
                        $error("Port %0d: length mismatch", p);
                        continue;
                    end

                    foreach (exp_pkt.data[i])
                        if (exp_pkt.data[i] != act_pkt.data[i])
                            $error("Port %0d: data mismatch at %0d", p, i);

                end
            end
        end

    endtask

endclass

endpackage