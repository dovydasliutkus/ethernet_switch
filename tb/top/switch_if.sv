interface switch_if (input logic clk);

    logic        clk;
    logic      reset;

    // // Activity indicators
    logic [3:0]  link_sync,   // High indicates a peer connection at the physical layer (cable plugged in)

    // Four GMII interfaces
    logic  [31:0] tx_data;     // (7:0)=TXD0 ... (31:24)=TXD3
    logic  [3:0]  tx_ctrl;     // (0)=TXC0 ... (3)=TXC3
    logic  [31:0] rx_data;     // (7:0)=RXD0 ... (31:24)=RXD3
    logic  [3:0]  rx_ctrl;     // (0)=RXC0 ... (3)=RXC3


    clocking cb @(posedge clk);
        output link_sync;
        input  tx_data;   
        input  tx_ctrl;  
        output rx_data;  
        output rx_ctrl;    
    endclocking

endinterface