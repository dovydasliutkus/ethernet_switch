interface fcs_if #(
  parameter int DATA_WIDTH = 8)
  (
    input logic clk
  );

  logic reset;
  logic start_of_frame;
  logic end_of_frame;
  logic [DATA_WIDTH-1:0] data_in;
  logic fcs_error;


  clocking cb @(posedge clk); // all outputs -> inputs and vice versa
    output reset;
    output start_of_frame;
    output end_of_frame;
    output data_in;
    input  fcs_error;
  endclocking

endinterface
