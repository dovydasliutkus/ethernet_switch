package crossbar_pkg;

    // ============================================================
    // PACKET CLASS
    // ============================================================
    class packet;

        int src;
        int dst;
        int len;
        byte data[$];

        function new(int src, int dst, int len);
            this.src = src;
            this.dst = dst;
            this.len = len;
        endfunction

    endclass


    // ============================================================
    // DRIVER
    // ============================================================
    class crossbar_driver #(parameter DATA_W=8, PORTS=4, LEN_WIDTH=11);

        virtual crossbar_if #(DATA_W,PORTS,LEN_WIDTH) vif;

        mailbox #(packet) exp_q[PORTS];
        mailbox #(int)    len_q[PORTS];

        function new(
            virtual crossbar_if #(DATA_W,PORTS,LEN_WIDTH) vif,
            mailbox #(packet) exp_q[PORTS],
            mailbox #(int)    len_q[PORTS]
        );
            this.vif   = vif;
            this.exp_q = exp_q;
            this.len_q = len_q;
        endfunction


        // ---------------- RESET ----------------
        task reset();

            vif.rst <= 0;  
            vif.cb.pkt_valid <= 0;
            vif.cb.data <= 0;

            repeat (5) @(vif.cb);

            vif.rst <= 1; 
            repeat (5) @(vif.cb);

        endtask


        // ---------------- GENERIC PACKET ----------------
        task send_packet(int src, int dst, int len);

            packet pkt = new(src, dst, len);

            // generate data
            for (int i = 0; i < len; i++)
                pkt.data.push_back(i);

            // publish expected
            exp_q[dst].put(pkt);

            // publish length for monitor
            len_q[dst].put(len);

            // drive DUT
            vif.cb.dst_port[src]  <= 1 << dst;
            vif.cb.pkt_len[src]   <= len;
            vif.cb.pkt_valid[src] <= 1;

            for (int i = 0; i < len; i++) begin
                vif.cb.data[src*DATA_W +: DATA_W] <= pkt.data[i];
                @(vif.cb);
            end

            vif.cb.pkt_valid[src] <= 0;
            @(vif.cb);

        endtask


        // ---------------- SIMPLE PACKET ----------------
        task send_simple_packet(int src, int dst);
            send_packet(src, dst, 8);
        endtask

    endclass


    // ============================================================
    // TX MONITOR (ORIGINAL LENGTH-AWARE)
    // ============================================================
    class tx_monitor #(parameter DATA_W=8, PORTS=4, LEN_WIDTH=11);

        virtual crossbar_if #(DATA_W,PORTS,LEN_WIDTH) vif;

        mailbox #(packet) act_q[PORTS];
        mailbox #(int)    len_q[PORTS];

        function new(
            virtual crossbar_if #(DATA_W,PORTS,LEN_WIDTH) vif,
            mailbox #(packet) act_q[PORTS],
            mailbox #(int)    len_q[PORTS]
        );
            this.vif   = vif;
            this.act_q = act_q;
            this.len_q = len_q;
        endfunction


        task run();

            byte data;
            packet pkt;

            int expected_len[PORTS];
            int count[PORTS];

            for (int p = 0; p < PORTS; p++) begin
                expected_len[p] = 0;
                count[p] = 0;
            end

            forever begin
                @(vif.cb);

                for (int p = 0; p < PORTS; p++) begin

                    if (vif.tx_ctrl[p]) begin

                        // new packet
                        if (count[p] == 0) begin
                            if (!len_q[p].try_get(expected_len[p])) begin
                                $error("Monitor: missing length for port %0d", p);
                                continue;
                            end
                            pkt = new(0, p, expected_len[p]);
                        end

                        data = vif.tx_data[p*DATA_W +: DATA_W];
                        pkt.data.push_back(data);

                        count[p]++;

                        if (count[p] == expected_len[p]) begin
                            act_q[p].put(pkt);
                            count[p] = 0;
                        end
                    end
                end
            end
        endtask

    endclass

endpackage