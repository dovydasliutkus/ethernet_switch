`timescale 1ns / 1ps

module tb_mac_learner();

    // ---------------------------------------------------------
    // 1. Signal Declarations
    // ---------------------------------------------------------
    logic        clk;
    logic        reset;
    logic        valid;
    logic [3:0]  src_port;
    logic [47:0] src_mac;
    logic [47:0] dst_mac;
    logic [3:0]  dst_port;
    logic        done;

    // ---------------------------------------------------------
    // 2. Instantiate DUT (Device Under Test)
    // ---------------------------------------------------------
    mac_learner dut (
        .clk(clk),
        .reset(reset),
        .valid(valid),
        .src_port(src_port),
        .src_mac(src_mac),
        .dst_mac(dst_mac),
        .dst_port(dst_port),
        .done(done)
    );

    // ---------------------------------------------------------
    // 3. Clock Generator (125 MHz -> 8ns period)
    // ---------------------------------------------------------
    initial begin
        clk = 0;
        forever #4 clk = ~clk; // 4ns low, 4ns high
    end

    // ---------------------------------------------------------
    // 4. Helper task to send packet requests cleanly
    // ---------------------------------------------------------
    task send_request(input logic [3:0] s_port, input logic [47:0] s_mac, input logic [47:0] d_mac);
        begin
            @(posedge clk);
            valid    <= 1'b1;
            src_port <= s_port;
            src_mac  <= s_mac;
            dst_mac  <= d_mac;
            
            @(posedge clk); // Cycle 1: BRAM read starts
            valid    <= 1'b0; // Important: Pulse valid for only 1 cycle
            
            @(posedge clk); // Cycle 2: Processing and writing
            wait(done);     // Wait for 'done' signal from the MAC Learner
            
            $display("Time: %0t | SRC_MAC: %h (Port %b) | DST_MAC: %h -> RESULT DST_PORT: %b", 
                      $time, s_mac, s_port, d_mac, dst_port);
                      
            @(posedge clk); // Small inter-packet gap
        end
    endtask

    // ---------------------------------------------------------
    // 5. Main Test Sequence
    // ---------------------------------------------------------
    initial begin
        $display("=== MAC LEARNER SIMULATION STARTED ===");
        
        // Initialize and Reset
        reset = 1;
        valid = 0;
        src_port = 0;
        src_mac = 0;
        dst_mac = 0;
        #20;
        reset = 0;
        #20;

        // --- TEST 1: Learn new MAC + Split Horizon Flood ---
        $display("\n--- TEST 1: Learn Host A and unknown dest (Flood) ---");
        // Host A (Port 1: 0001) sends to unknown Host B.
        // Expected: Flood mask excluding incoming Port 1 -> 1110
        send_request(4'b0001, 48'hAAAA_BBBB_CCCC, 48'h1111_2222_3333);

        // --- TEST 2: Lookup with a hit ---
        $display("\n--- TEST 2: Host B replies to Host A (Hit) ---");
        // Host B (Port 2: 0010) replies to Host A.
        // Expected: Port 1 mask -> 0001
        send_request(4'b0010, 48'h1111_2222_3333, 48'hAAAA_BBBB_CCCC);

        // --- TEST 3: Hardcore Hash Collision and LRU eviction ---
        $display("\n--- TEST 3: 2-way LRU eviction test (Forced Collisions) ---");
        // We use 12-bit (3 hex character) offsets to guarantee the exact same XOR hash (0xABC)
        
        // 1. MAC_X: 12-bit offset in the lowest segment. Fills Way 1.
        send_request(4'b0100, 48'h000_000_000_ABC, 48'hFFFF_FFFF_FFFF);
        
        // 2. MAC_Y: 12-bit offset in the 2nd segment. Collision! Fills Way 2.
        send_request(4'b1000, 48'h000_000_ABC_000, 48'hFFFF_FFFF_FFFF);
        
        // 3. MAC_X speaks again. Updates LRU (MAC_Y is now considered older).
        send_request(4'b0100, 48'h000_000_000_ABC, 48'hFFFF_FFFF_FFFF);
        
        // 4. MAC_Z: 12-bit offset in the highest segment. Both ways full.
        // Hardware must evict MAC_Y because it is the oldest!
        send_request(4'b0001, 48'hABC_000_000_000, 48'hFFFF_FFFF_FFFF);

        // --- TEST 4: Verify eviction ---
        $display("\n--- TEST 4: Verify eviction (Lookup for evicted MAC_Y) ---");
        // Search for MAC_Y. Since it was overwritten by Z, it must be a Miss.
        // Expected: Flood mask excluding incoming port -> 1110
        send_request(4'b0001, 48'h999_888_777_666, 48'h000_000_ABC_000);

        #100;
        $display("=== SIMULATION FINISHED SUCCESSFULLY ===");
        $stop; // Stop ModelSim execution
    end

endmodule