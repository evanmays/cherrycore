
// An AI inference core that only does relu!!!
// Send it fp16, it send fp16.relu() back!
// Modified Ben Marshall's uart top module
module top (
input               clk     , // Top level system clock input.
input               sw_0    , // Slide switches.
input               sw_1    , // Slide switches.
input   wire        uart_rxd, // UART Recieve pin.
output  wire        uart_txd, // UART transmit pin.
output  wire [7:0]  led
);

// Clock frequency in hertz.
parameter CLK_HZ = 50000000;
parameter BIT_RATE =   4800;
parameter PAYLOAD_BITS = 8;

wire [PAYLOAD_BITS-1:0]  uart_rx_data;
wire        uart_rx_valid;
wire        uart_rx_break;
reg reading_msw; // most significant word. first 8 bits of fp16
reg is_negative;

wire        uart_tx_busy;
reg [PAYLOAD_BITS-1:0]  uart_tx_data;
reg        uart_tx_en;

reg  [PAYLOAD_BITS-1:0]  led_reg;
assign      led = led_reg;

// ------------------------------------------------------------------------- 

always @(posedge clk) begin
    uart_tx_en  <=  uart_rx_valid;
    if(!sw_0) begin
        led_reg <= 8'hF0;
        reading_msw <= 1;
    end else if(uart_rx_valid) begin
        led_reg <= uart_rx_data[7:0];
        reading_msw <= ~reading_msw;
        if (reading_msw) is_negative <= uart_rx_data[7];
        // relu!!!
        uart_tx_data <= reading_msw
                        ? uart_rx_data[7]
                            ? 8'b0
                            : uart_rx_data
                        : is_negative
                            ? 8'b0
                            : uart_rx_data;
        //uart_tx_data <= uart_rx_data;
    end
end


// ------------------------------------------------------------------------- 

//
// UART RX
uart_rx #(
.BIT_RATE(BIT_RATE),
.PAYLOAD_BITS(PAYLOAD_BITS),
.CLK_HZ  (CLK_HZ  )
) i_uart_rx(
.clk          (clk          ), // Top level system clock input.
.resetn       (sw_0         ), // Asynchronous active low reset.
.uart_rxd     (uart_rxd     ), // UART Recieve pin.
.uart_rx_en   (1'b1         ), // Recieve enable
.uart_rx_break(uart_rx_break), // Did we get a BREAK message?
.uart_rx_valid(uart_rx_valid), // Valid data recieved and available.
.uart_rx_data (uart_rx_data )  // The recieved data.
);

//
// UART Transmitter module.
//
uart_tx #(
.BIT_RATE(BIT_RATE),
.PAYLOAD_BITS(PAYLOAD_BITS),
.CLK_HZ  (CLK_HZ  )
) i_uart_tx(
.clk          (clk          ),
.resetn       (sw_0         ),
.uart_txd     (uart_txd     ),
.uart_tx_en   (uart_tx_en   ),
.uart_tx_busy (uart_tx_busy ),
.uart_tx_data (uart_tx_data ) 
);


endmodule
