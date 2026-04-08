package fcs_pkg;

  class fcs_class;

    virtual fcs_if vif;

    function new(virtual fcs_if vif);
      this.vif = vif;
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

    //////////////////////// RESET SEQUENCE ////////////////////////////////
    task automatic reset_seq();
      vif.cb.reset <= 'b0;
      repeat(5) @(vif.cb);
      vif.cb.reset <='b1;
    endtask
  endclass

endpackage
