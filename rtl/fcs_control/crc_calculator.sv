// =============================================================================
// File        : fcs_check_parallel.sv
// Description : Parallel (8 bit input) CRC-32 checker.
// 1. Inverts first and last 4 bytes
// 2. Calculates the ramainder rem[M(X)/G(X)]
// =============================================================================

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
    input   logic        i_dstmac_ren,
    input   logic        i_srcmac_ren,

    output  logic        o_length_empty,
    output  logic        o_status_empty,
    output  logic        o_dstmac_empty,
    output  logic        o_srcmac_empty,
    output  logic        o_abort
    );

    typedef enum logic [2:0] {
        IDLE,       // Waits for i_rx_ctrl to go high
        PREAMBLE,   // Skips 8 preamble/SFD bytes before CRC starts
        DST_MAC,    // Collects 6 bytes
        SRC_MAC,    // Collects 6 bytes
        PAYLOAD    // Payload repeats for the length determined in PL_LENGTH
    } state_t;

    state_t state, state_n;

    logic [31:0]  rem_reg, rem_reg_n;
    logic [10:0]  counter, counter_n;    // global byte counter: increments every byte, 11 bits covers max Ethernet frame
    logic [7:0]   byte_in;               // inverted or straight i_data fed to CRC
    logic calc_en, crc_valid;

    logic [47:0]  dst_mac_int, src_mac_int, dst_mac_int_n, src_mac_int_n; // Internal mac address signals

    // FIFO signals
    logic length_wen, status_wen, dstmac_wen, srcmac_wen;
    logic [10:0] length_fifo_data;
    logic abort_n;

    // Signals for monitoring with SignalTap - use keep so they are not optimized away
    (* keep *) logic length_fifo_full, status_fifo_full, dstmac_fifo_full, srcmac_fifo_full;

    packet_length_fifo u_length_fifo (
        .clock  (clk             ),
        .data   (length_fifo_data),
        .wrreq  (length_wen     ),
        .rdreq  (i_length_ren   ),
        .sclr   (~reset         ),
        .empty  (o_length_empty ),
        .full   (length_fifo_full),
        .q      (o_packet_length)
    );

    packet_status_fifo u_status_fifo (
        .clock  (clk            ),
        .data   (crc_valid      ),
        .wrreq  (status_wen     ),
        .rdreq  (i_status_ren   ),
        .sclr   (~reset         ),
        .empty  (o_status_empty ),
        .full   (status_fifo_full),
        .q      (o_valid        )
    );

    dst_mac_fifo u_dst_mac_fifo (
	    .clock  (clk ),
	    .data   (dst_mac_int ),
	    .rdreq  (i_dstmac_ren ),
	    .wrreq  (dstmac_wen ),
	    .sclr   (~reset ),
	    .empty  (o_dstmac_empty ),
	    .full   (dstmac_fifo_full),
	    .q      (dst_mac )
	);

    src_mac_fifo u_src_mac_fifo (
	    .clock  (clk ),
	    .data   (src_mac_int ),
	    .rdreq  (i_srcmac_ren ),
	    .wrreq  (srcmac_wen ),
	    .sclr   (~reset ),
	    .empty  (o_srcmac_empty ),
	    .full   (srcmac_fifo_full),
	    .q      (src_mac )
	);

    always_ff @(posedge clk) begin
        if (!reset) begin
            state           <= IDLE;
            rem_reg         <= '0;
            counter         <= '0;
            dst_mac_int     <= '0;
            src_mac_int     <= '0;
            o_abort           <= 1'b0;
        end
        else begin
            state           <= state_n;
            rem_reg         <= rem_reg_n;
            counter         <= counter_n;
            dst_mac_int     <= dst_mac_int_n;
            src_mac_int     <= src_mac_int_n;
            o_abort           <= abort_n;
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
        dstmac_wen  = 1'b0;
        srcmac_wen  = 1'b0;
        abort_n         = o_abort;
        length_fifo_data = counter + 11'd8;
        dst_mac_int_n   = dst_mac_int;
        src_mac_int_n   = src_mac_int;

        case (state)

        // --------------------------------------------------------
        IDLE: begin
            if (!i_rx_ctrl) begin
                abort_n = 1'b0;
            end else if (!o_abort) begin
                counter_n = 11'd1;
                state_n   = PREAMBLE;
            end
        end

        // --------------------------------------------------------
        // Skip 8 preamble/SFD bytes (indices 0-7); on byte index 8 start CRC.
        PREAMBLE: begin
            if (i_rx_ctrl) begin
                if (counter == 11'd8) begin
                    byte_in            = ~i_data;   // CRC pre-conditioning (init = 0xFFFFFFFF)
                    dst_mac_int_n[7:0] = i_data;
                    calc_en            = 1'b1;
                    counter_n          = 11'd1;
                    state_n            = DST_MAC;
                end else begin
                    counter_n = counter + 1;
                end
            end else begin
                state_n   = IDLE;
                counter_n = '0;
            end
        end

        // --------------------------------------------------------
        DST_MAC: begin
            calc_en   = 1'b1;
            counter_n = counter + 1;

            if (counter < 6) begin
                byte_in  = (counter < 4) ? ~i_data : i_data;  // bytes 1-3 inverted, 4-5 as-is
                dst_mac_int_n[counter*8 +: 8] = i_data;  // counter=1→[15:8], 2→[23:16] ... 5→[47:40]
            end else begin
                // Write dst_mac to the FIFO
                dstmac_wen = 1'b1;
                // counter=6: first byte of src_mac_int
                src_mac_int_n[7:0]  = i_data;
                state_n             = SRC_MAC;
            end
        end

        // --------------------------------------------------------
        // Bytes 7-11 go into src_mac, byte 12 is EtherType (CRC only, no register).
        SRC_MAC: begin
            calc_en   = 1'b1;
            counter_n = counter + 1;
            byte_in   = i_data;

            if (counter < 12) begin
                src_mac_int_n[(counter-6)*8 +: 8] = byte_in;  // counter=7→[15:8], 8→[23:16] ... 11→[47:40]
            end else begin
                // Write src_mac to the FIFO
                srcmac_wen = 1'b1;
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
                 $display("[%0t] CRC REM = %08x", $time, rem_reg);
                crc_valid  = (rem_reg == 32'hFFFF_FFFF);
                // crc_valid = 1'b1;// amal debug
                length_wen = 1'b1;  // push byte count into length FIFO
                status_wen = 1'b1;  // push CRC result into status FIFO
                state_n    = IDLE;
            end
        end
        endcase

        // Global abort: PHY dropped rx_ctrl early
        // if (state != IDLE && !i_rx_ctrl) begin
        //     state_n   = IDLE;
        //     counter_n = '0;
        // end
        
        // Global abort: Packet length too long, write length and status for dump
        // i_rx_ctrl guard prevents double-fire when a max-size frame ends normally
        // (counter reaches 1519 the cycle i_rx_ctrl drops for a 1518-byte frame).
        if (counter > 11'd1518 && i_rx_ctrl) begin
            state_n          = IDLE;
            counter_n        = '0;
            // NEED the below line because rx_ctrl is still high and until abort registers another byte will come into the data FIFO (without this the data FIFO slowly fills up when oversized packets)
            length_fifo_data = counter + 11'd9;  // +1 relative to normal end-of-packet
            length_wen       = 1'b1;
            status_wen       = 1'b1;
            abort_n          = 1'b1;
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
