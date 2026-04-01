// =============================================================================
// File        : fcs_check_parallel.sv
// Description : Parallel (8 bit input) CRC-32 checker.
// 1. Inverts first and last 4 bytes
// 2. Calculates the ramainder rem[M(X)/G(X)]
// =============================================================================

// IMPORTANT: After processing a frame needs to be at least 1 cycle in IDLE so that rem_reg is reset to zeros

module fcs_check_parallel(
    input   logic        clk,
    input   logic        reset,      // synchronous active-high
    input   logic        i_rx_ctrl,
    input   logic [7:0]  i_data,

    output  logic [47:0] src_mac,
    output  logic [47:0] dst_mac,
    output  logic [10:0] o_packet_length,
    output  logic        o_valid
);

    typedef enum logic [1:0] {
        IDLE,       // Starts shifting data when i_rx_ctrl goes high
        DST_MAC,    // Collects 6 bytes
        SRC_MAC,    // Collects 6 bytes
        PL_LENGTH,  // Payload length - 2 bytes
        PAYLOAD,    // Payload repeats for the length determined in PL_LENGTH
        FCS
    } state_t;

    state_t state, state_n;

    logic [31:0] rem_reg, rem_reg_n;
    logic [5:0]  counter, counter_n;     // counts 0 to 31 TODO set counter to minimum size
    logic [7:0]  byte_in;                 // Holds the inverted/non-inverted i_data value based on start and end of frame
    logic calc_en;

    logic [47:0] dst_mac_n, src_mac_n;
    logic [15:0] pl_length, pl_length_n;

    // Truncate the redundant part of packet length, add length for MACs, FCS, length
    assign o_packet_length = pl_length[10:0] + 11'd18;

    always_ff @(posedge clk) begin
        if (reset) begin
            state       <= IDLE;
            rem_reg     <= '0;
            counter     <= '0;
            dst_mac     <= '0;
            src_mac     <= '0;
            pl_length   <= '0;
        end
        else begin
            state       <= state_n;
            rem_reg     <= rem_reg_n;
            counter     <= counter_n;
            dst_mac     <= dst_mac_n;
            src_mac     <= src_mac_n;
            pl_length   <= pl_length_n;
        end
    end

    always_comb begin
        // defaults
        state_n     = state;
        counter_n   = counter;
        byte_in     = i_data;
        calc_en     = 1'b0;
        o_valid     = 1'b0;
        dst_mac_n   = dst_mac;
        src_mac_n   = src_mac;
        pl_length_n = pl_length;

        case (state)

        // --------------------------------------------------------
        IDLE: begin
            if (i_rx_ctrl) begin // i_rx_ctrl goes high start recording data
                byte_in         = ~i_data;  // invert first byte
                dst_mac_n[7:0]  = ~i_data;  // Record first byte of destination mac
                calc_en   = 1'b1;
                counter_n = '0;       // first byte consumed this cycle
                state_n   = DST_MAC;
            end
        end

        // --------------------------------------------------------
        DST_MAC: begin
            calc_en = 1'b1;

            if (counter < 5) begin
                byte_in = (counter < 3) ? ~i_data : i_data;  // invert bytes 1-3, pass bytes 4-5 as-is
                dst_mac_n[(counter+1)*8 +: 8]  = byte_in; // Variable part select starting at bit 8 assign (counter+1)*8 number of bits
                counter_n = counter + 1;
            end else begin
                counter_n   = '0;       // Reset counter
                byte_in     = i_data;  
                src_mac_n[7:0] = byte_in;
                state_n   = SRC_MAC;
                
            end
        end

        // --------------------------------------------------------
        SRC_MAC: begin
             calc_en = 1'b1;

            if (counter < 5) begin
                byte_in = i_data;
                src_mac_n[(counter+1)*8 +: 8]  = byte_in; // Variable part select starting at bit 8 assign (counter+1)*8 number of bits
                counter_n = counter + 1;
            end else begin
                counter_n        = '0;       // Reset counter
                byte_in          = i_data;  
                pl_length_n[7:0] = byte_in;
                state_n          = PL_LENGTH;
                
            end 
        end
        // --------------------------------------------------------
        PL_LENGTH: begin
            calc_en           = 1'b1;
            pl_length_n[15:8] = byte_in;
            counter_n         = '0;       // Reset counter
            state_n           = PAYLOAD;
        end
        PAYLOAD: begin
            calc_en = 1'b1;
            
            if (counter < pl_length) begin
                byte_in = i_data;
                counter_n = counter + 1;
            end else begin
                counter_n = '0;       // Reset counter
                byte_in   = ~i_data;  // First byte of FCS so invert
                state_n   = FCS;     
            end
        end

        // --------------------------------------------------------
        FCS: begin
            calc_en = 1'b1;
            byte_in   = ~i_data;   // Invert FCS bytes
            counter_n = counter + 1;

            // After 4 FCS bytes
            if (counter == 3) begin
                o_valid = (rem_reg != 32'b0);
                state_n   = IDLE;
            end // TODO mayb emove byte_in assignment to an else statement here
        end
        // After checking the o_validr the reg latches the next byte_in before going to IDLE, on serial that wasn't an issue
        endcase

        // Global abort: PHY dropped rx_ctrl early
        if (state != IDLE && !i_rx_ctrl) begin
            state_n   = IDLE;
            counter_n = '0;
            // TODO here we need some handling that would make the data_fifo drop the frame
        end
    end

// Python generated combinational CRC logic
always_comb begin
    if(calc_en) begin
        rem_reg_n = rem_reg; // default assignment

        rem_reg_n[0] = rem_reg[24] ^ rem_reg[30] ^ byte_in[0];
        rem_reg_n[1] = rem_reg[24] ^ rem_reg[25] ^ rem_reg[30] ^ rem_reg[31] ^ byte_in[1];
        rem_reg_n[2] = rem_reg[24] ^ rem_reg[25] ^ rem_reg[26] ^ rem_reg[30] ^ rem_reg[31] ^ byte_in[2];
        rem_reg_n[3] = rem_reg[25] ^ rem_reg[26] ^ rem_reg[27] ^ rem_reg[31] ^ byte_in[3];
        rem_reg_n[4] = rem_reg[24] ^ rem_reg[26] ^ rem_reg[27] ^ rem_reg[28] ^ rem_reg[30] ^ byte_in[4];
        rem_reg_n[5] = rem_reg[24] ^ rem_reg[25] ^ rem_reg[27] ^ rem_reg[28] ^ rem_reg[29] ^ rem_reg[30] ^ rem_reg[31] ^ byte_in[5];
        rem_reg_n[6] = rem_reg[25] ^ rem_reg[26] ^ rem_reg[28] ^ rem_reg[29] ^ rem_reg[30] ^ rem_reg[31] ^ byte_in[6];
        rem_reg_n[7] = rem_reg[24] ^ rem_reg[26] ^ rem_reg[27] ^ rem_reg[29] ^ rem_reg[31] ^ byte_in[7];
        rem_reg_n[8] = rem_reg[0] ^ rem_reg[24] ^ rem_reg[25] ^ rem_reg[27] ^ rem_reg[28];
        rem_reg_n[9] = rem_reg[1] ^ rem_reg[25] ^ rem_reg[26] ^ rem_reg[28] ^ rem_reg[29];
        rem_reg_n[10] = rem_reg[2] ^ rem_reg[24] ^ rem_reg[26] ^ rem_reg[27] ^ rem_reg[29];
        rem_reg_n[11] = rem_reg[3] ^ rem_reg[24] ^ rem_reg[25] ^ rem_reg[27] ^ rem_reg[28];
        rem_reg_n[12] = rem_reg[4] ^ rem_reg[24] ^ rem_reg[25] ^ rem_reg[26] ^ rem_reg[28] ^ rem_reg[29] ^ rem_reg[30];
        rem_reg_n[13] = rem_reg[5] ^ rem_reg[25] ^ rem_reg[26] ^ rem_reg[27] ^ rem_reg[29] ^ rem_reg[30] ^ rem_reg[31];
        rem_reg_n[14] = rem_reg[6] ^ rem_reg[26] ^ rem_reg[27] ^ rem_reg[28] ^ rem_reg[30] ^ rem_reg[31];
        rem_reg_n[15] = rem_reg[7] ^ rem_reg[27] ^ rem_reg[28] ^ rem_reg[29] ^ rem_reg[31];
        rem_reg_n[16] = rem_reg[8] ^ rem_reg[24] ^ rem_reg[28] ^ rem_reg[29];
        rem_reg_n[17] = rem_reg[9] ^ rem_reg[25] ^ rem_reg[29] ^ rem_reg[30];
        rem_reg_n[18] = rem_reg[10] ^ rem_reg[26] ^ rem_reg[30] ^ rem_reg[31];
        rem_reg_n[19] = rem_reg[11] ^ rem_reg[27] ^ rem_reg[31];
        rem_reg_n[20] = rem_reg[12] ^ rem_reg[28];
        rem_reg_n[21] = rem_reg[13] ^ rem_reg[29];
        rem_reg_n[22] = rem_reg[14] ^ rem_reg[24];
        rem_reg_n[23] = rem_reg[15] ^ rem_reg[24] ^ rem_reg[25] ^ rem_reg[30];
        rem_reg_n[24] = rem_reg[16] ^ rem_reg[25] ^ rem_reg[26] ^ rem_reg[31];
        rem_reg_n[25] = rem_reg[17] ^ rem_reg[26] ^ rem_reg[27];
        rem_reg_n[26] = rem_reg[18] ^ rem_reg[24] ^ rem_reg[27] ^ rem_reg[28] ^ rem_reg[30];
        rem_reg_n[27] = rem_reg[19] ^ rem_reg[25] ^ rem_reg[28] ^ rem_reg[29] ^ rem_reg[31];
        rem_reg_n[28] = rem_reg[20] ^ rem_reg[26] ^ rem_reg[29] ^ rem_reg[30];
        rem_reg_n[29] = rem_reg[21] ^ rem_reg[27] ^ rem_reg[30] ^ rem_reg[31];
        rem_reg_n[30] = rem_reg[22] ^ rem_reg[28] ^ rem_reg[31];
        rem_reg_n[31] = rem_reg[23] ^ rem_reg[29];
    end else begin
            // Reset in IDLE state
            rem_reg_n = (state == IDLE) ? 32'b0 : rem_reg;
        end
end

endmodule
