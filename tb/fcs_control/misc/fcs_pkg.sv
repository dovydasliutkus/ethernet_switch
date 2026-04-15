package fcs_pkg;

  class fcs_class;

    virtual fcs_if vif;

    // Reflected CRC-32 lookup table (polynomial 0xEDB88320)
    // Matches the parallel equations used in crc_calculator.sv
    logic [31:0] crc32_table[256];

    function new(virtual fcs_if vif);
      logic [31:0] c;
      this.vif = vif;
      // Build reflected CRC-32 table
      for (int i = 0; i < 256; i++) begin
        c = 32'(unsigned'(i));
        for (int j = 0; j < 8; j++) begin
          if (c[0]) c = 32'hEDB88320 ^ (c >> 1);
          else      c = c >> 1;
        end
        crc32_table[i] = c;
      end
    endfunction

    // change for ethernet realistic payload
    localparam int PAYLOAD_LEN = 480; // payload length in bits (e.g., 60 bytes for Ethernet)

    /////////////////////// GENERATE PALOAD //////////////////////////////////
    function logic [PAYLOAD_LEN-1:0] generate_payload();
      logic [PAYLOAD_LEN-1:0] payload;

      // randomize payload with 0s and 1s
      for (int i = 0; i < PAYLOAD_LEN; i++)
        payload[i] = $urandom_range(0,1);

      return payload;
    endfunction


    /////////////////////// CALCULATE CRC ////////////////////////////////////
    function logic [31:0] calc_crc(
        logic [PAYLOAD_LEN-1:0] payload
      );
      logic [31:0]  crc;
      logic         fb; // feedback bit
      
      crc = 32'hFFFFFFFF;
      for (int i = PAYLOAD_LEN-1; i >= 0; i--) begin // Process each bit from MSB to LSB
          fb = payload[i] ^ crc[31];
          crc = {crc[30:0], 1'b0};
          if (fb)
              crc ^= 32'h04C11DB7;
      end
      return ~crc;
    endfunction

    /////////////////////// BYTE-LEVEL CRC (reflected CRC-32) ///////////////
    // Computes reflected CRC-32 over an arbitrary-length byte array.
    // init=0xFFFFFFFF, final XOR=0xFFFFFFFF — standard Ethernet convention.
    function automatic logic [31:0] calc_crc_bytes(
        input logic [7:0] data[],
        input int         len
    );
      logic [31:0] crc;
      crc = 32'hFFFF_FFFF;
      for (int i = 0; i < len; i++)
        crc = (crc >> 8) ^ crc32_table[crc[7:0] ^ data[i]];
      return ~crc;
    endfunction

    /////////////////////// GENERATE RANDOM PACKET //////////////////////////
    // Builds a complete Ethernet frame of pkt_length bytes with a valid FCS.
    //
    // Frame layout:
    //   [0 ..  5]              dst_mac   (6 B, random)
    //   [6 .. 11]              src_mac   (6 B, random)
    //   [12.. 13]              EtherType (2 B, random)
    //   [14 .. pkt_length-5]   payload   (variable, random)
    //   [pkt_length-4 .. pkt_length-1]  FCS (4 B, computed, little-endian)
    //
    // pkt_length : total frame size INCLUDING the 4-byte FCS.
    //              Minimum 18 (14-byte header + 0-byte payload + 4-byte FCS).
    //              Standard Ethernet minimum is 64.
    task automatic generate_packet(
        input  int         pkt_length,
        output logic [7:0] pkt[]
    );
      int data_len;
      logic [31:0] fcs;

      if (pkt_length < 18) begin
        $error("[generate_packet] pkt_length=%0d is below minimum of 18", pkt_length);
        return;
      end

      data_len = pkt_length - 4; // bytes before FCS
      pkt = new[pkt_length];

      // Randomise header + payload
      for (int i = 0; i < data_len; i++)
        pkt[i] = $urandom_range(0, 255);

      // Compute FCS over header + payload
      fcs = calc_crc_bytes(pkt[0:data_len-1], data_len);

      // Append FCS little-endian (LSB first — standard Ethernet wire order)
      pkt[data_len + 0] = fcs[ 7: 0];
      pkt[data_len + 1] = fcs[15: 8];
      pkt[data_len + 2] = fcs[23:16];
      pkt[data_len + 3] = fcs[31:24];
    endtask

    //////////////////////// RESET SEQUENCE ////////////////////////////////
    task automatic reset_seq();
      vif.cb.reset <= 'b0;
      repeat(5) @(vif.cb);
      vif.cb.reset <='b1;
    endtask
  endclass

endpackage
