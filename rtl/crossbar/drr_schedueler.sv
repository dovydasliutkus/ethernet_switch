module drr_scheduler #(
    parameter int PORT_ID   = 0,    // which output port schedueler manages (0-3)
    parameter int QUANTUM   = 1518,  // Bytes of credit added per DRR turn
    parameter int LEN_WIDTH = 11,   // Packet length field width (for 1518 byte packet)
    parameter int OCC_WIDTH = 13    // Occupancy counter width from Quartus FIFO IP (depth 4096 )
)(
    input logic                      clk,
    input logic                     reset,

    //////////////// FCS/control signals ////////////////
    input logic[3:0]                packet_valid,
    input logc[3:0]                 dst_port[3:0], 
    input logic [LEN_WIDTH-1:0]     i_pkt_len[3:0],   // byte length of packet at input i


    //////////////// buffer block signals ////////////////
    input  logic [OCC_WIDTH-1:0]    occupancy  [3:0],
    input  logic [3:0]              fifo_full,
    output logic [3:0]              write_enable,       
    output logic [3:0]              read_enable,   

    //////////////// tx status  ////////////////
    output logic                    o_tx_ctrl
);

endmodule
   