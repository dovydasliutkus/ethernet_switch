module output_control(
    
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


endmodule 