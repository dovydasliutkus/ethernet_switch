import fcs_pkg::*;

module tb_fcs_parallel_check;

  // Clock
  logic clk = 0;
  localparam int CLK_PERIOD = 10;

  always #(CLK_PERIOD/2) clk = ~clk;

  // Interface and class
  fcs_if #(.DATA_WIDTH(8)) i_fcs_if (clk);
  fcs_class fcs;

  initial
    fcs = new(i_fcs_if);

  // DUT instance
  fcs_parallel_check dut (
    .clk(i_fcs_if.clk),
    .reset(i_fcs_if.reset),
    .start_of_frame(i_fcs_if.start_of_frame),
    .end_of_frame(i_fcs_if.end_of_frame),
    .data_in(i_fcs_if.data_in),
    .fcs_error(i_fcs_if.fcs_error)
  );

  // Signals
  logic [fcs.PAYLOAD_LEN-1:0] payload;
  logic [fcs.PAYLOAD_LEN-1:0] payload_neg;
  logic [31:0] crc;
  logic [31:0] crc_neg;
  logic [fcs.PAYLOAD_LEN+31:0] frame;

  ///////////////////////////// TEST TASKS //////////////////////////////
  task automatic send_frame();
    int total_bits = fcs.PAYLOAD_LEN + 32;

    // Send first byte with start_of_frame
    i_fcs_if.cb.start_of_frame <= 1'b1;
    i_fcs_if.cb.data_in <= frame[total_bits-1 -: 8];
    @(i_fcs_if.cb);
    i_fcs_if.cb.start_of_frame <= 1'b0;

    // Remaining bytes
    for (int i = total_bits-8-1; i >= 0; i -= 8) begin
      i_fcs_if.cb.data_in <= frame[i -: 8];
      i_fcs_if.cb.end_of_frame <= (i == 31); // first FCS byte
      @(i_fcs_if.cb);
      i_fcs_if.cb.end_of_frame <= 1'b0;
    end

    @(i_fcs_if.cb); // final CRC update
    @(i_fcs_if.cb); // allow fcs_error pulse
  endtask

  task automatic test_fixed_payload();

    payload = 512'h0010_A47B_EA80_0012_3456_7890_0800_4500_002E_B3FE_0000_8011_0540_C0A8_002C_C0A8_0004_0400_0400_001A_2DE8_0001_0203_0405_0607_0809_0A0B_0C0D_0E0F_1011;
    crc = 32'hE6C53DB2;
    payload_neg = {~payload[479:448],payload[447:0]}; // only complement the MSB 32 bits of the payload (for debugging)
    crc = 32'hE6C53DB2;
    crc_neg = ~crc; // for debugging
    frame = {payload, crc};

    send_frame();

    if (i_fcs_if.cb.fcs_error == 1'b0)
      $display("TEST 1 (FIXED PAYLOAD, CORRECT FCS): PASS");
    else begin
      $display("TEST 1 (FIXED PAYLOAD, CORRECT FCS): FAIL");
      $display("got fcs_error: %b", i_fcs_if.cb.fcs_error);
    end
  endtask


  task automatic test_fixed_payload_wrong_crc();

    payload = 512'h0010_A47B_EA80_0012_3456_7890_0800_4500_002E_B3FE_0000_8011_0540_C0A8_002C_C0A8_0004_0400_0400_001A_2DE8_0001_0203_0405_0607_0809_0A0B_0C0D_0E0F_1011;
    crc = 32'hE6C53DB1;
    frame = {payload, crc};

    send_frame();

    if (i_fcs_if.cb.fcs_error == 1'b1)
      $display("TEST 2 (FIXED PAYLOAD, WRONG FCS): PASS");
    else begin
      $display("TEST 2 (FIXED PAYLOAD, WRONG FCS): FAIL");
      $display("got fcs_error: %b", i_fcs_if.cb.fcs_error);
    end
  endtask

  task automatic test_random_payload();

    payload = fcs.generate_payload();
    crc = fcs.calc_crc(payload);
    frame = {payload, crc};

    send_frame();

    if (i_fcs_if.cb.fcs_error == 1'b0)
      $display("TEST 3 (RANDOM PAYLOAD, CORRECT FCS): PASS");
    else begin
      $display("TEST 3 (RANDOM PAYLOAD, CORRECT FCS): FAIL");
      $display("got fcs_error: %b", i_fcs_if.cb.fcs_error);
    end
  endtask

  task automatic test_random_payload_wrong_crc();

    payload = fcs.generate_payload();
    crc = fcs.calc_crc(payload);
    crc[31:30] = ~crc[31:30];
    frame = {payload, crc};

    send_frame();

    if (i_fcs_if.cb.fcs_error == 1'b1)
      $display("TEST 4 (RANDOM PAYLOAD, WRONG FCS): PASS");
    else begin
      $display("TEST 4 (RANDOM PAYLOAD, WRONG FCS): FAIL");
      $display("got fcs_error: %b", i_fcs_if.cb.fcs_error);
    end
  endtask


  ///////////////////////////// RUN ALL TESTS //////////////////////////////
  initial begin
    fcs.reset_seq();
    test_fixed_payload();
    test_fixed_payload_wrong_crc();
    test_random_payload();
    test_random_payload_wrong_crc();
    $stop();
  end

endmodule