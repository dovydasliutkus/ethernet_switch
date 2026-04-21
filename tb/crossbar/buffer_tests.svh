// ============================================================
// BUFFER TESTS (T4–T6)
// ============================================================


// T4: FIFO Integrity Under Load
// Multiple packets to SAME destination → must preserve order
task automatic run_test_fifo_integrity(output int err_cnt);

    int src = 0;
    int dst = 1;
    int num_pkts = 5;
    int pkt_len  = 8;

    err_cnt = 0;
    global_err_cnt = 0;

    $display("\nT4: FIFO Integrity Under Load");

    drv.reset_sequence();

    // Send multiple packets into same FIFO
    for (int i = 0; i < num_pkts; i++) begin
        drv.send_packet(src, dst, pkt_len);
    end

    // Wait long enough for all packets to exit
    repeat (2000) @(vif.cb);

    err_cnt = global_err_cnt;

    if (err_cnt == 0)
        $display("PASS: FIFO integrity maintained under load");
    else
        $error("FAIL: FIFO corruption detected (%0d errors)", err_cnt);

endtask



// T5: FIFO Empty Behavior
// No packets -> no TX activity allowed
task automatic run_test_fifo_empty(output int err_cnt);

    err_cnt = 0;

    $display("\nT5: FIFO Empty Behavior");

    drv.reset_sequence();

    // Observe system for some cycles
    repeat (200) begin
        @(vif.cb);

        if (vif.tx_ctrl !== '0) begin
            err_cnt++;
            $error("FAIL: TX active while FIFO should be empty");
        end
    end

    if (err_cnt == 0)
        $display("PASS: No TX activity when FIFO is empty");

endtask



// T6: FIFO Full Behavior
// Fill FIFO, then push more -> system must remain stable
task automatic run_test_fifo_full(output int err_cnt);

    int src = 0;
    int dst = 1;

    err_cnt = 0;
    global_err_cnt = 0;

    $display("\nT6: FIFO Full Behavior");

    drv.reset_sequence();

    // Step 1: Fill FIFO heavily
    repeat (40) begin
        drv.send_packet(src, dst, 100);
    end

    // Step 2: Try to overload
    repeat (10) begin
        drv.send_packet(src, dst, 200);
    end

    // Step 3: Let system drain
    repeat (5000) @(vif.cb);

    err_cnt = global_err_cnt;

    if (err_cnt == 0)
        $display("PASS: FIFO full handled without corruption");
    else
        $error("FAIL: Errors detected under FIFO full condition (%0d)", err_cnt);

endtask