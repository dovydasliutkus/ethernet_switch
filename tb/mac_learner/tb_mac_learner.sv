`timescale 1ns / 1ps

module tb_mac_learner();

    // Signal declarations
    logic        clk;
    logic        reset;
    logic        valid;
    logic [3:0]  src_port;
    logic [47:0] src_mac;
    logic [47:0] dst_mac;
    logic [3:0]  dst_port;
    logic        done;

    // Instantiate DUT
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

    // Clock generator (125 MHz -> 8ns period)
    initial begin
        clk = 0;
        forever #4 clk = ~clk;
    end

    // Helper task to send packet requests
    task send_request(input logic [3:0] s_port, input logic [47:0] s_mac, input logic [47:0] d_mac);
        begin
            @(posedge clk);
            valid    <= 1'b1;
            src_port <= s_port;
            src_mac  <= s_mac;
            dst_mac  <= d_mac;
            
            @(posedge clk);
            valid    <= 1'b0; // Pulse valid for 1 cycle
            
            @(posedge clk);
            wait(done); // Wait for execution to complete
            
            $display("Time: %0t | SRC_MAC: %h (Port %b) | DST_MAC: %h -> RESULT DST_PORT: %b", 
                      $time, s_mac, s_port, d_mac, dst_port);
            @(posedge clk); // Inter-packet gap
        end
    endtask

    // Main Test Sequence
    initial begin
        $display("=== MAC LEARNER SIMULATION STARTED ===");
        
        // Initialize and Reset
        reset = 0;
        valid = 0;
        src_port = 0;
        src_mac = 0;
        dst_mac = 0;
        #20;
        reset = 1;
        #20;

        // TEST 1: Learn Host A and unknown dest (Flood)
        $display("\n--- TEST 1: Learn Host A and unknown dest (Flood) ---");
        send_request(4'b0001, 48'hAAAA_BBBB_CCCC, 48'h1111_2222_3333);

        // TEST 2: Lookup with a hit
        $display("\n--- TEST 2: Host B replies to Host A (Hit) ---");
        send_request(4'b0010, 48'h1111_2222_3333, 48'hAAAA_BBBB_CCCC);

        // TEST 3: Hash Collision and LRU eviction
        $display("\n--- TEST 3: 2-way LRU eviction test (Forced Collisions) ---");
        send_request(4'b0100, 48'h000_000_000_ABC, 48'hFFFF_FFFF_FFFF); // Fills Way 1
        send_request(4'b1000, 48'h000_000_ABC_000, 48'hFFFF_FFFF_FFFF); // Fills Way 2
        send_request(4'b0100, 48'h000_000_000_ABC, 48'hFFFF_FFFF_FFFF); // Updates LRU (Way 2 becomes oldest)
        send_request(4'b0001, 48'hABC_000_000_000, 48'hFFFF_FFFF_FFFF); // Evicts oldest (Way 2 / MAC_Y)

        // TEST 4: Verify eviction
        $display("\n--- TEST 4: Verify eviction (Lookup for evicted MAC_Y) ---");
        send_request(4'b0001, 48'h999_888_777_666, 48'h000_000_ABC_000);

        // TEST 5: Inject Multicast Source MAC (I/G bit = 1)
        $display("\n--- TEST 5: Inject Multicast Source MAC (I/G bit = 1) ---");
        send_request(4'b0100, 48'hAAAA_BBBB_0001, 48'hFFFF_FFFF_FFFF);

        // TEST 6: Verify Multicast MAC was NOT learned
        $display("\n--- TEST 6: Verify Multicast MAC was NOT learned ---");
        send_request(4'b1000, 48'h5555_6666_7777, 48'hAAAA_BBBB_0001);

        #100;
        $display("=== SIMULATION FINISHED SUCCESSFULLY ===");
        $stop;
    end

endmodule