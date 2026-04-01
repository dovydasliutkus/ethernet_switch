// =============================================================================
// File        : fcs_check_parallel.sv
// Description : Parallel (8 bit input) CRC-32 checker.
// 1. Inverts first and last 4 bytes
// 2. Calculates the ramainder rem[M(X)/G(X)]
// =============================================================================

// TODO top level has to make sure nothing is written into crc_calculator if data fifo is full
// don't need to worry about crc fifos being full as they are sized to fit the maximum number of smallest data packets
module crc_calculator(
    input   logic        clk,
    input   logic        reset,      // synchronous active-high
    input   logic        i_rx_ctrl,
    input   logic [7:0]  i_data,

    output  logic [47:0] src_mac,
    output  logic [47:0] dst_mac,
    output  logic [10:0] o_packet_length,
    output  logic        o_valid,

    // FIFO signals
    input   logic        i_length_ren,
    input   logic        i_status_ren,

    output  logic        o_length_empty,
    output  logic        o_status_empty
    );

    typedef enum logic [1:0] {
        IDLE,       // Starts shifting data when i_rx_ctrl goes high
        DST_MAC,    // Collects 6 bytes
        SRC_MAC,    // Collects 6 bytes
        PAYLOAD    // Payload repeats for the length determined in PL_LENGTH
    } state_t;

    state_t state, state_n;

    logic [31:0]  rem_reg, rem_reg_n;
    logic [10:0]  counter, counter_n;    // global byte counter: increments every byte, 11 bits covers max Ethernet frame
    logic [7:0]   byte_in;               // inverted or straight i_data fed to CRC
    logic calc_en, crc_valid;

    logic [47:0]  dst_mac_n, src_mac_n;

    // FIFO signals
    logic length_wen, status_wen;
    // TODO regenerate FIFOs without full and usedw signals
    packet_length_fifo u_length_fifo (
        .clock  (clk            ),
        .data   (counter        ),  // write: current byte count at end of frame
        .wrreq  (length_wen     ),  // write enable: pulsed once per frame
        .rdreq  (i_length_ren   ),  // read enable: driven by Output Control
        .empty  (o_length_empty ),  // empty flag: for Output Control to know when it has something to read
        .full   (),
        .q      (o_packet_length),
        .usedw  ()
    );

    packet_status_fifo u_status_fifo (
        .clock  (clk            ),
        .data   (crc_valid      ),  // write: 1=CRC ok, 0=bad frame
        .wrreq  (status_wen     ),  // write enable: pulsed once per frame
        .rdreq  (i_status_ren   ),  // read enable: driven by downstream consumer
        .empty  (o_status_empty ), 
        .full   (),  
        .q      (o_valid        ),
        .usedw  ()
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            state       <= IDLE;
            rem_reg     <= '0;
            counter     <= '0;
            dst_mac     <= '0;
            src_mac     <= '0;
        end
        else begin
            state       <= state_n;
            rem_reg     <= rem_reg_n;
            counter     <= counter_n;
            dst_mac     <= dst_mac_n;
            src_mac     <= src_mac_n;
        end
    end

    always_comb begin
        // defaults
        state_n     = state;
        counter_n   = counter;
        byte_in     = i_data;
        calc_en     = 1'b0;
        crc_valid   = 1'b0;
        length_wen  = 1'b0;
        status_wen  = 1'b0;
        dst_mac_n   = dst_mac;
        src_mac_n   = src_mac;

        case (state)

        // --------------------------------------------------------
        IDLE: begin
            if (i_rx_ctrl) begin
                byte_in        = ~i_data;   // byte 0: inverted (first of the 4 CRC-preconditioned bytes)
                dst_mac_n[7:0] = ~i_data;   // counter will be 1 after this cycle
                calc_en        = 1'b1;
                counter_n      = 11'd1;     // byte 0 consumed this cycle
                state_n        = DST_MAC;
            end
        end

        // --------------------------------------------------------
        DST_MAC: begin
            calc_en   = 1'b1;
            counter_n = counter + 1;

            if (counter < 6) begin
                byte_in  = (counter < 4) ? ~i_data : i_data;  // bytes 1-3 inverted, 4-5 as-is
                dst_mac_n[counter*8 +: 8] = byte_in;  // counter=1→[15:8], 2→[23:16] ... 5→[47:40]
            end else begin
                // counter=6: first byte of src_mac
                src_mac_n[7:0] = i_data;
                state_n        = SRC_MAC;
            end
        end

        // --------------------------------------------------------
        // Bytes 7-11 go into src_mac, byte 12 is EtherType (CRC only, no register).
        SRC_MAC: begin
            calc_en   = 1'b1;
            counter_n = counter + 1;
            byte_in   = i_data;

            if (counter < 12) begin
                src_mac_n[(counter-6)*8 +: 8] = byte_in;  // counter=7→[15:8], 8→[23:16] ... 11→[47:40]
            end else begin
                // counter=12: EtherType byte 0, feed to CRC only, then move on
                state_n = PAYLOAD;
            end
        end

        // --------------------------------------------------------
        // All remaining bytes (EtherType byte 1 + payload + FCS) pass through here.
        // counter holds the total frame byte count when i_rx_ctrl drops.
        PAYLOAD: begin
            if (i_rx_ctrl) begin
                calc_en   = 1'b1;
                byte_in   = i_data;
                counter_n = counter + 1;
            end else begin
                crc_valid  = (rem_reg == 32'hFFFF_FFFF);
                length_wen = 1'b1;  // push byte count into length FIFO
                status_wen = 1'b1;  // push CRC result into status FIFO
                state_n    = IDLE;
            end
        end
        endcase

        // Global abort: PHY dropped rx_ctrl early
        if (state != IDLE && !i_rx_ctrl) begin
            state_n   = IDLE;
            counter_n = '0;
            // TODO here we need some handling that would make the data_fifo drop the frame
            // SOLUTION: If i_rx_ctrl is cutoff during transmission the crc value will be wrong - Output control will flush.
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
