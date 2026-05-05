module mac_learner (
    input  logic        clk,
    input  logic        reset,
    
    // Control and Data ports
    input  logic        valid,
    input  logic [3:0]  src_port, // 1-hot encoded incoming port
    input  logic [47:0] src_mac,  // Address for learning
    input  logic [47:0] dst_mac,  // Address for lookup
  
    // Outputs
    output logic [3:0]  dst_port, // 1-hot encoded dest port (or flood mask)
    output logic        done
);

    // Pipeline registers
    logic [47:0] src_mac_reg;
    logic [47:0] dst_mac_reg;
    logic [3:0]  src_port_reg;

    // Hash generators (Combinational)
    logic [11:0] src_hash;
    logic [11:0] dst_hash;

    // XOR fold 48-bit MAC to 12-bit hash
    assign src_hash = src_mac[47:36] ^ src_mac[35:24] ^ src_mac[23:12] ^ src_mac[11:0];
    assign dst_hash = dst_mac[47:36] ^ dst_mac[35:24] ^ dst_mac[23:12] ^ dst_mac[11:0];

    // 2-Way Set Associative BRAM (M9K blocks)
    // Way 1
    (* ramstyle = "M9K, no_rw_check" *) logic        valid1_ram [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) logic [47:0] mac1_ram   [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) logic [3:0]  port1_ram  [0:4095];

    // Way 2
    (* ramstyle = "M9K, no_rw_check" *) logic        valid2_ram [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) logic [47:0] mac2_ram   [0:4095];
    (* ramstyle = "M9K, no_rw_check" *) logic [3:0]  port2_ram  [0:4095];

    // LRU Bit: 0 = Way 1 is older, 1 = Way 2 is older
    (* ramstyle = "M9K, no_rw_check" *) logic        lru_ram    [0:4095];

    // Main FSM
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        PROCESS = 2'b01
    } state_t;

    state_t state;

    // BRAM read data registers
    logic        src_v1, src_v2, dst_v1, dst_v2;
    logic [47:0] src_m1, src_m2, dst_m1, dst_m2;
    logic [3:0]  src_p1, src_p2, dst_p1, dst_p2;
    logic        src_lru;
    logic [11:0] src_hash_reg; 

    always_ff @(posedge clk) begin
        if (!reset) begin
            // Reset FSM and pipeline (BRAMs clear on power-up)
            state    <= IDLE;
            done     <= 1'b0;
            dst_port <= 4'b0000;
            
            src_mac_reg  <= '0;
            dst_mac_reg  <= '0;
            src_port_reg <= '0;
        end else begin
            case (state)
                // --- Stage 1: Read BRAM ---
                IDLE: begin
                    done <= 1'b0; 
                    
                    if (valid) begin
                        // Lookup data (DST)
                        dst_v1 <= valid1_ram[dst_hash];
                        dst_m1 <= mac1_ram[dst_hash];
                        dst_p1 <= port1_ram[dst_hash];
                        
                        dst_v2 <= valid2_ram[dst_hash];
                        dst_m2 <= mac2_ram[dst_hash];
                        dst_p2 <= port2_ram[dst_hash];
                        
                        // Learning data (SRC)
                        src_v1  <= valid1_ram[src_hash];
                        src_m1  <= mac1_ram[src_hash];
                        
                        src_v2  <= valid2_ram[src_hash];
                        src_m2  <= mac2_ram[src_hash];
                        
                        src_lru <= lru_ram[src_hash];

                        // Buffer inputs for Stage 2
                        src_mac_reg  <= src_mac;
                        dst_mac_reg  <= dst_mac;
                        src_port_reg <= src_port;
                        src_hash_reg <= src_hash;
                        
                        state <= PROCESS;
                    end
                end

                // --- Stage 2: Evaluate and Write ---
                PROCESS: begin
                    
                    // A) Lookup Evaluation
                    if (dst_v1 && (dst_m1 == dst_mac_reg)) begin
                        // Way 1 Hit: Check split horizon
                        if (dst_p1 == src_port_reg)
                            dst_port <= 4'b0000; // Drop
                        else
                            dst_port <= dst_p1;  // Forward
                    end 
                    else if (dst_v2 && (dst_m2 == dst_mac_reg)) begin
                        // Way 2 Hit: Check split horizon
                        if (dst_p2 == src_port_reg)
                            dst_port <= 4'b0000; // Drop
                        else
                            dst_port <= dst_p2;  // Forward
                    end 
                    else begin
                        // Miss: Flood to all except incoming port
                        dst_port <= 4'b1111 & ~src_port_reg;
                    end

                    // B) Learning & LRU Update
                    // Learn only Unicast MACs (I/G bit == 0)
                    if (src_mac_reg[0] == 1'b0) begin
                        
                        // Case 1: Hit in Way 1
                        if (src_v1 && (src_m1 == src_mac_reg)) begin
                            port1_ram[src_hash_reg] <= src_port_reg; 
                            lru_ram[src_hash_reg]   <= 1'b1;         
                        end
                        // Case 2: Hit in Way 2
                        else if (src_v2 && (src_m2 == src_mac_reg)) begin
                            port2_ram[src_hash_reg] <= src_port_reg; 
                            lru_ram[src_hash_reg]   <= 1'b0;         
                        end
                        // Case 3: Miss (Allocate new)
                        else begin
                            // Use Way 1 if empty or LRU points to it
                            if (!src_v1 || (src_v1 && src_v2 && src_lru == 1'b0)) begin
                                valid1_ram[src_hash_reg] <= 1'b1;
                                mac1_ram[src_hash_reg]   <= src_mac_reg;
                                port1_ram[src_hash_reg]  <= src_port_reg;
                                lru_ram[src_hash_reg]    <= 1'b1;    
                            end
                            // Otherwise use Way 2
                            else begin
                                valid2_ram[src_hash_reg] <= 1'b1;
                                mac2_ram[src_hash_reg]   <= src_mac_reg;
                                port2_ram[src_hash_reg]  <= src_port_reg;
                                lru_ram[src_hash_reg]    <= 1'b0;    
                            end
                        end
                    end

                    done  <= 1'b1; 
                    state <= IDLE; 
                end
            endcase
        end
    end

endmodule