// ============================================================
// BASIC TESTS (T1–T3)
// ============================================================

task automatic wait_cycles(int n);
    repeat (n) @(vif.cb);
endtask


// T1: Reset Behavior
task automatic run_test_reset(output int err_cnt);

    err_cnt = 0;
    global_err_cnt = 0;

    $display("\nT1: Reset Behavior");

    drv.reset_sequence();

    wait_cycles(10);

    if (vif.tx_ctrl !== '0) begin
        $error("FAIL: tx_ctrl not zero after reset: %b", vif.tx_ctrl);
        err_cnt++;
    end else begin
        $display("PASS: tx_ctrl is zero after reset");
    end

    if (vif.tx_data !== '0) begin
        $error("FAIL: tx_data not zero after reset: %h", vif.tx_data);
        err_cnt++;
    end else begin
        $display("PASS: tx_data is zero after reset");
    end

endtask


// T2: Single Packet Forwarding
task automatic run_test_single_packet(output int err_cnt);

    int src = 0;
    int dst = 1;
    int len = 8;

    $display("\nT2: Single Packet Forwarding");

    global_err_cnt = 0;

    drv.send_packet(src, dst, len);

    repeat (200) @(vif.cb);

    err_cnt = global_err_cnt;

    if (err_cnt == 0)
        $display("PASS: Packet forwarded correctly");
    else
        $error("FAIL: %0d mismatches detected", err_cnt);

endtask


// T3: All Port Connectivity
task automatic run_test_all_ports(output int err_cnt);

    int len = 6;

    $display("\nT3: All Port Connectivity");

    global_err_cnt = 0;

    for (int src = 0; src < PORTS; src++) begin
        for (int dst = 0; dst < PORTS; dst++) begin

            $display("Testing src=%0d -> dst=%0d", src, dst);

            drv.send_packet(src, dst, len);

            repeat (200) @(vif.cb);

        end
    end

    err_cnt = global_err_cnt;

    if (err_cnt == 0)
        $display("PASS: All port combinations transmitted correctly");
    else
        $error("FAIL: %0d mismatches detected", err_cnt);

endtask