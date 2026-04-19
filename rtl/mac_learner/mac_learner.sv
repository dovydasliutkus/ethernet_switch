module mac_learner (
    input  logic        clk,
    input  logic        reset,
    
    // Control and Data ports (from FCS)
    input  logic        valid,
    input  logic [3:0]  src_port, // 1-hot encoded incoming port
    input  logic [47:0] src_mac,  // Address for learning
    input  logic [47:0] dst_mac,  // Address for lookup
    
    // Outputs (to FCS / Crossbar)
    output logic [3:0]  dst_port, // 1-hot encoded destination port (or Flood mask)
    output logic        done
);
    // Internal Registers for Pipeline Timing Fix
    logic [47:0] src_mac_reg;
    logic [47:0] dst_mac_reg;
    logic [3:0]  src_port_reg;
    
    // 1. HASH GENERATORS (Combinational logic, 0 cycles)
    logic [11:0] src_hash;
    logic [11:0] dst_hash;

    // XOR folding for learning (SRC) and lookup (DST)
    // Splits the 48-bit MAC into four 12-bit slices and XORs them together
    assign src_hash = src_mac[47:36] ^ src_mac[35:24] ^ src_mac[23:12] ^ src_mac[11:0];
    assign dst_hash = dst_mac[47:36] ^ dst_mac[35:24] ^ dst_mac[23:12] ^ dst_mac[11:0];

    // 2. 2-WAY BRAM MEMORY ARRAYS (Synthesized as M9K blocks in Quartus)
    // Way 1
    (* ramstyle = "M9K, no_rw_check" *) logic        valid1_ram [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) logic [47:0] mac1_ram   [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) logic [3:0]  port1_ram  [0:4095];
    // Way 2
    (* ramstyle = "M9K, no_rw_check" *) logic        valid2_ram [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) logic [47:0] mac2_ram   [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) logic [3:0]  port2_ram  [0:4095];
    // LRU Bit (0 = Way 1 is older, 1 = Way 2 is older)
    (* ramstyle = "M9K, no_rw_check" *) logic        lru_ram    [0:4095];

    // 3. MAIN STATE MACHINE (FSM) AND PIPELINE REGISTERS
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        PROCESS = 2'b01
    } state_t;

    state_t state;

    // Registers for memory read data (Pipeline Stage 1 -> 2)
    logic        src_v1, src_v2, dst_v1, dst_v2;
    logic [47:0] src_m1, src_m2, dst_m1, dst_m2;
    logic [3:0]  src_p1, src_p2, dst_p1, dst_p2;
    logic        src_lru;
    
    logic [11:0] src_hash_reg; // Store the hash for writing in the 2nd cycle

    always_ff @(posedge clk) begin
        if (reset) begin
            state    <= IDLE;
            done     <= 1'b0;
            dst_port <= 4'b0000;
            
            src_mac_reg  <= '0;
            dst_mac_reg  <= '0;
            src_port_reg <= '0;
            
            // Optional: Clear valid bits on reset (useful for simulation)
            for (int i=0; i<4096; i++) begin
                valid1_ram[i] <= 1'b0;
                valid2_ram[i] <= 1'b0;
            end
        end else begin
            case (state)
                // --- CYCLE 1: WAIT AND READ BRAM ---
                IDLE: begin
                    done <= 1'b0; // Deassert done flag
                    if (valid) begin
                        // Read BRAM data at the calculated hash indices
                        // Lookup (DST) data:
                        dst_v1 <= valid1_ram[dst_hash];
                        dst_m1 <= mac1_ram[dst_hash];
                        dst_p1 <= port1_ram[dst_hash];
                        dst_v2 <= valid2_ram[dst_hash];
                        dst_m2 <= mac2_ram[dst_hash];
                        dst_p2 <= port2_ram[dst_hash];
                        
                        // Learning (SRC) data:
                        src_v1  <= valid1_ram[src_hash];
                        src_m1  <= mac1_ram[src_hash];
                        src_v2  <= valid2_ram[src_hash];
                        src_m2  <= mac2_ram[src_hash];
                        src_lru <= lru_ram[src_hash];
                        
                        // SAVE INPUTS FOR CYCLE 2 (PIPELINE FIX)
                        src_mac_reg  <= src_mac;
                        dst_mac_reg  <= dst_mac;
                        src_port_reg <= src_port;
                        src_hash_reg <= src_hash;
                        
                        state <= PROCESS;
                    end
                end

                // --- CYCLE 2: EVALUATE, WRITE AND SPLIT HORIZON ---
                PROCESS: begin
                    // A) EVALUATE LOOKUP (Using registered dst_mac)
                    if (dst_v1 && (dst_m1 == dst_mac_reg)) begin
                        dst_port <= dst_p1; // Hit in Way 1
                    end 
                    else if (dst_v2 && (dst_m2 == dst_mac_reg)) begin
                        dst_port <= dst_p2; // Hit in Way 2
                    end 
                    else begin
                        // Address not found; Split Horizon Flood: All ports (1111) except incoming
                        dst_port <= 4'b1111 & ~src_port_reg;
                    end

                    // B) LEARNING AND LRU UPDATE (Using registered src_mac and src_port)
                    // Case 1: Host is already known in Way 1
                    if (src_v1 && (src_m1 == src_mac_reg)) begin
                        port1_ram[src_hash_reg] <= src_port_reg; // Update port if host moved
                        lru_ram[src_hash_reg]   <= 1'b1;         // Way 1 was used, point LRU to Way 2
                    end
                    // Case 2: Host is already known in Way 2
                    else if (src_v2 && (src_m2 == src_mac_reg)) begin
                        port2_ram[src_hash_reg] <= src_port_reg; 
                        lru_ram[src_hash_reg]   <= 1'b0;         // Way 2 was used, point LRU to Way 1
                    end
                    // Case 3: NEW MAC (MISS) - Evict or write into an empty slot
                    else begin
                        // If Way 1 is empty, OR both are full and LRU points to Way 1
                        if (!src_v1 || (src_v1 && src_v2 && src_lru == 1'b0)) begin
                            valid1_ram[src_hash_reg] <= 1'b1;
                            mac1_ram[src_hash_reg]   <= src_mac_reg;
                            port1_ram[src_hash_reg]  <= src_port_reg;
                            lru_ram[src_hash_reg]    <= 1'b1; // Point LRU to the other way
                        end
                        // Otherwise write to Way 2
                        else begin
                            valid2_ram[src_hash_reg] <= 1'b1;
                            mac2_ram[src_hash_reg]   <= src_mac_reg;
                            port2_ram[src_hash_reg]  <= src_port_reg;
                            lru_ram[src_hash_reg]    <= 1'b0; // Point LRU to the other way
                        end
                    end

                    done  <= 1'b1; // Signal FCS that the port mask is ready
                    state <= IDLE; // Return to waiting state
                end
            endcase
        end
    end

endmodule