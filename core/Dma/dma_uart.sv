function [15:0] fp16;
	input [17:0] cherry_float;
	begin
		fp16 = cherry_float[17:2]; // chop off least signifcant 2 mantissa bits
	end
endfunction

// Low performance DMA engine
// Only supports one direction at a time and casts your cherry float to fp16
// Only supports 7 bit host address.
module dma_uart #(parameter CLK_HZ=50000000) (
input               clk     , // Top level system clock input.
input               reset ,
input   [17:0]      dma_dat_w,
input   [6:0]       dma_dat_addr,
input               we,
output  reg         busy,

// board pins
input   wire        uart_rxd, // UART Recieve pin.
output  wire        uart_txd  // UART transmit pin.

);
// def access_dma(f, write_enable):
//     set busy to true
//     write_cherry_float(f, addr) if write_enable else read_cherry_float(f, addr)
//     set busy to false
//
// def read_cherry_float(f, addr):
//     # implement
//     # set dma_dat_r and sram_mem_addr so we can edit sram from this module
//
// def write_cherry_float(f, addr):
//     send write at addr command
//     while True:
//         if not uart_tx_busy:
//             break
//     send most signifcant 8 bits of fp16(f)
//     while True:
//         if not uart_tx_busy:
//             break
//     send least signficant 8 bits of fp16_cast(f)
//     while True:
//         if not uart_tx_busy:
//             break

enum {  IDLE,
        SEND_WRITE_COMMAND_0,
        SEND_WRITE_COMMAND_1,
        SEND_WRITE_COMMAND_2,
        SEND_MSB_0,
        SEND_MSB_1,
        SEND_MSB_2,
        SEND_LSB_0,
        SEND_LSB_1,
        SEND_LSB_2,
        FINISH
    } S;
reg [7:0]   uart_tx_data;
reg         uart_tx_en;
wire        uart_tx_busy;
reg [15:0]  float;
always @(posedge clk) begin
    case (S)
        IDLE: begin
            if (we) begin
                busy    = 1;
                S       = SEND_WRITE_COMMAND_0;
                float   = fp16(dma_dat_w);
            end
        end
        SEND_WRITE_COMMAND_0:  begin
            uart_tx_en      = 1;
            uart_tx_data    = {1'b1, dma_dat_addr};
            S               = SEND_WRITE_COMMAND_1;
        end
        SEND_WRITE_COMMAND_1: begin
            uart_tx_en = 0;
            S = SEND_WRITE_COMMAND_2;
        end
        SEND_WRITE_COMMAND_2: begin
            if (!uart_tx_busy) begin
                S = SEND_MSB_0;
            end
        end
        SEND_MSB_0: begin
            uart_tx_en      = 1;
            uart_tx_data    = float[15:8];
            S               = SEND_MSB_1;
        end
        SEND_MSB_1: begin
            uart_tx_en = 0;
            S = SEND_MSB_2;
        end
        SEND_MSB_2: begin
            if (!uart_tx_busy) begin
                S = SEND_LSB_0;
            end
        end
        SEND_LSB_0: begin
            uart_tx_en      = 1;
            uart_tx_data    = float[7:0];
            S               = SEND_LSB_1;
        end
        SEND_LSB_1: begin
            uart_tx_en = 0;
            S = SEND_LSB_2;
        end
        SEND_LSB_2: begin
            if (!uart_tx_busy) begin
                S = FINISH;
            end
        end
        FINISH: begin
            busy    = 0;
            S       = IDLE;
        end
    endcase
    if (reset) begin
        S               = IDLE;
        busy            = 0;
        uart_tx_en      = 0;
        uart_tx_data    = 0;
    end
end


uart_tx #(
.BIT_RATE(4800),
.PAYLOAD_BITS(8),
.CLK_HZ  (CLK_HZ  )
) i_uart_tx(
.clk          (clk          ),
.resetn       (!reset       ),
.uart_txd     (uart_txd     ),
.uart_tx_en   (uart_tx_en   ),
.uart_tx_busy (uart_tx_busy ),
.uart_tx_data (uart_tx_data ) 
);


endmodule