// repeatedly sends the same fp16 over and over.
// useful for e2e testing with real uart communication to real host computer running python

module top #(parameter CLK_HZ=50000000) (
input               clk     , // Top level system clock input.
input               sw_0 , // reset switch
input   wire        uart_rxd, // UART Recieve pin.
output  wire        uart_txd,  // UART transmit pin.
output  wire [7:0]  led
);
wire [17:0] cherry_float;
wire [6:0]   addr;
wire         we;
assign cherry_float  = 18'd34133;
assign addr          = 7'd120;
assign we            = 1'b1;

dma_uart dma (
.clk(clk),
.reset(sw_0),
.dma_dat_w(cherry_float),
.dma_dat_addr(addr),
.we(we),
.busy(led[0]),

// board pins
.uart_rxd(uart_rxd), // UART Recieve pin.
.uart_txd(uart_txd)  // UART transmit pin.

);

endmodule