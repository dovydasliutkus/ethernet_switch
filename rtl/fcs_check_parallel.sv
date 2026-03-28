// =============================================================================
// File        : fcs_check_parallel.sv
// Description : Parallel (8 bit input) CRC-32 checker.
// 1. Inverts first and last 4 bytes
// 2. Calculates the ramainder rem[M(X)/G(X)]
// =============================================================================

// IMPORTANT: After processing a frame needs to be at least 1 cycle in IDLE so that rem_reg is reset to zeros

module fcs_check_parallel(
    input  logic        clk,
    input  logic        reset,              // synchronous reset
    input  logic        start_of_frame,
    input  logic        end_of_frame,       // first bit of FCS field
    input  logic [7:0]  data_in,
    output logic        fcs_error
);

    typedef enum logic [1:0] {
        IDLE,
        DATA,
        FCS
    } state_t;

    state_t state, state_n;

    logic [31:0] rem_reg, rem_reg_n;
    logic [1:0]  counter, counter_n;     // counts 0 to 31
    logic [7:0]  byte_in;                 // Holds the inverted/non-inverted data_in value based on start and end of frame
    logic calc_en;

    always_ff @(posedge clk) begin
        if (reset) begin
            state   <= IDLE;
            rem_reg <= '0;
            counter <= '0;
        end
        else begin
            state   <= state_n;
            rem_reg <= rem_reg_n;
            counter <= counter_n;
        end
    end

    always_comb begin
        // defaults
        state_n   = state;
        counter_n = counter;
        byte_in   = data_in;
        calc_en   = 1'b0;
        fcs_error = 1'b0;

        case (state)

        // --------------------------------------------------------
        IDLE: begin
            if (start_of_frame) begin
                byte_in   = ~data_in;   // invert first byte
                calc_en   = 1'b1;
                counter_n = '0;       // first byte consumed this cycle
                state_n   = DATA;
            end
        end

        // --------------------------------------------------------
        DATA: begin
            calc_en = 1'b1;

            if (end_of_frame) begin
                // This byte is the first FCS byte — invert it
                byte_in   = ~data_in;
                counter_n = '0;   // first FCS byte consumed this cycle
                state_n   = FCS;
            end else if (counter < 3) begin 
                // Invert first 4 bytes (bytes 1-3 here; byte 0 handled in IDLE)
                counter_n = counter + 1;
                byte_in   = ~data_in;
            end else begin
                // Shift in an arbitrary amount of data without inversion until end_of_frame comes 
                byte_in   = data_in; 
            end            
        end

        // --------------------------------------------------------
        FCS: begin
            calc_en = 1'b1;
            byte_in   = ~data_in;   // Invert FCS bytes
            counter_n = counter + 1;

            // After 4 FCS bytes
            if (counter == 3) begin
                fcs_error = (rem_reg != 32'b0);
                state_n   = IDLE;
            end
        end
        // After checking the fcs_error the reg latches the next byte_in before going to IDLE, on serial that wasn't an issue
        endcase
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
