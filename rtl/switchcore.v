module switchcore (
    input  wire        clk,
    input  wire        reset,

    // Activity indicators
    input  wire [3:0]  link_sync,   // High indicates a peer connection at the physical layer (cable plugged in)

    // Four GMII interfaces
    output reg  [31:0] tx_data,     // (7:0)=TXD0 ... (31:24)=TXD3
    output reg  [3:0]  tx_ctrl,     // (0)=TXC0 ... (3)=TXC3
    input  wire [31:0] rx_data,     // (7:0)=RXD0 ... (31:24)=RXD3
    input  wire [3:0]  rx_ctrl      // (0)=RXC0 ... (3)=RXC3
);

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        tx_data[7:0]   <= 8'b0;
        tx_data[15:8]  <= 8'b0;
        tx_ctrl[0]     <= 1'b0;
        tx_ctrl[1]     <= 1'b0;
    end else begin
        tx_data[7:0]   <= rx_data[15:8];
        tx_data[15:8]  <= rx_data[7:0];
        tx_ctrl[0]     <= rx_ctrl[1];
        tx_ctrl[1]     <= rx_ctrl[0];
    end
end

endmodule