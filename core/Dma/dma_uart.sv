// when in doubt, play with this toy https://evanw.github.io/float-toy/
function [15:0] fp16;
	input [17:0] cherry_float;
	begin
		fp16 = cherry_float[17:2]; // chop off least signifcant 2 mantissa bits
	end
endfunction

// lol this conversion and fp16 conversion are wrong. TODO: Lets do fp32 dma so conversions can be easier
function [17:0] cherry_float;
	input [15:0] fp16;
	begin
		cherry_float = {fp16, 2'd0}; // add 2 least signifcant 2
	end
endfunction

// Low performance DMA engine
// Only supports one direction at a time and casts your cherry float to fp16
// Only supports 7 bit host address.
module dma_uart #(parameter CLK_HZ=50000000) (
input                       clk,
input                       reset,
input   dma_stage_2_instr   instr,

output  reg                 busy,

// Control cache
output  dma_stage_3_instr   cache_write_port,

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
//     send read addr command
//     while True:
//         if not uart_tx_busy:
//             break
//     while True:
//          if uart_rx_valid:
//              store most signifcant byte
//              break
//     while True:
//          if uart_rx_valid:
//              set cache_write_port with original instruction and data as cherry_float( {MSB, LSB} )
//              break
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

enum {  // start
        IDLE,

        // write_cherry_float()
        SEND_WRITE_COMMAND_0,
        SEND_WRITE_COMMAND_1,
        SEND_WRITE_COMMAND_2,
        SEND_MSB_0,
        SEND_MSB_1,
        SEND_MSB_2,
        SEND_LSB_0,
        SEND_LSB_1,
        SEND_LSB_2,

        // read_cherry_float()
        SEND_READ_COMMAND_0,
        SEND_READ_COMMAND_1,
        SEND_READ_COMMAND_2,
        RECV_MSB_0,
        RECV_LSB_0,

        // end
        FINISH
    } S;

// cisa_mem_write
reg [7:0]   uart_tx_data;
reg         uart_tx_en;
wire        uart_tx_busy;
reg [15:0]  float;

// cisa_mem_read
reg [7:0]           recv_msb;
dma_stage_2_instr   temp_instr;
wire                uart_rx_valid;
wire [7:0]          uart_rx_data;

// cisa_mem_*
reg [6:0]  addr;
always_ff @(posedge clk) begin
    case (S)
        IDLE: begin
            cache_write_port <= 0; // for mem_read // just override write enable to save power // reset here instead of finish state because when dma in finish state dcache still frozen. if you reset in finish state, dcache never knew the instruction existed.
            if (instr.raw_instr_data.valid) begin
                busy    <= 1;
                addr    <= instr.raw_instr_data.main_mem_addr;
                if (instr.raw_instr_data.mem_we) begin
                    S       <= SEND_WRITE_COMMAND_0;
                    float   <= fp16(instr.dat);
                end else begin
                    // 16'h5248 for 50.25
                    // 16'hD248 for -50.25
                    S       <= SEND_READ_COMMAND_0;
                    temp_instr <= instr;
                end
            end         
        end
        //
        // def read_cherry_float(f, addr):
        //
        SEND_READ_COMMAND_0:  begin
            uart_tx_en      <= 1;
            uart_tx_data    <= {1'b0, addr};
            S               <= SEND_READ_COMMAND_1;
        end
        SEND_READ_COMMAND_1: begin
            uart_tx_en <= 0;
            S <= SEND_READ_COMMAND_2;
        end
        SEND_READ_COMMAND_2: begin
            if (!uart_tx_busy) begin
                S <= RECV_MSB_0;
            end
        end
        RECV_MSB_0: begin
            if (uart_rx_valid) begin
                recv_msb <= uart_rx_data;
                S <= RECV_LSB_0;
            end
        end
        RECV_LSB_0: begin
            if (uart_rx_valid) begin
                cache_write_port            <= temp_instr; //TODO: since yosys language built in wont let me cache_write_port.raw_instr_data im just overrwriting the entire thing. figure out how to fix
                cache_write_port[39:22]     <= cherry_float({recv_msb, uart_rx_data});// 16'hD248
                S <= FINISH;
           end
        end
        //
        // def write_cherry_float(f, addr):
        //
        SEND_WRITE_COMMAND_0:  begin
            uart_tx_en      <= 1;
            uart_tx_data    <= {1'b1, addr};
            S               <= SEND_WRITE_COMMAND_1;
        end
        SEND_WRITE_COMMAND_1: begin
            uart_tx_en <= 0;
            S <= SEND_WRITE_COMMAND_2;
        end
        SEND_WRITE_COMMAND_2: begin
            if (!uart_tx_busy) begin
                S <= SEND_MSB_0;
            end
        end
        SEND_MSB_0: begin
            uart_tx_en      <= 1;
            uart_tx_data    <= float[15:8];
            S               <= SEND_MSB_1;
        end
        SEND_MSB_1: begin
            uart_tx_en <= 0;
            S <= SEND_MSB_2;
        end
        SEND_MSB_2: begin
            if (!uart_tx_busy) begin
                S <= SEND_LSB_0;
            end
        end
        SEND_LSB_0: begin
            uart_tx_en      <= 1;
            uart_tx_data    <= float[7:0];
            S               <= SEND_LSB_1;
        end
        SEND_LSB_1: begin
            uart_tx_en <= 0;
            S <= SEND_LSB_2;
        end
        SEND_LSB_2: begin
            if (!uart_tx_busy) begin
                S <= FINISH;
            end
        end

        // end
        FINISH: begin
            busy    <= 0;
            S       <= IDLE;
        end
    endcase
    if (reset) begin
        S               <= IDLE;
        busy            <= 0;
        uart_tx_en      <= 0;
        uart_tx_data    <= 0;
        cache_write_port  <= 0;
        recv_msb        <= 0;
        temp_instr      <= 0;
    end
end


uart_tx #(
.BIT_RATE(19200),
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

uart_rx #(
.BIT_RATE(19200),
.PAYLOAD_BITS(8),
.CLK_HZ  (CLK_HZ  )
) i_uart_rx(
.clk          (clk          ),
.resetn       (!reset       ),
.uart_rxd     (uart_rxd     ),
.uart_rx_en   (1'b1         ),
.uart_rx_valid(uart_rx_valid ),
.uart_rx_data (uart_rx_data)
);


endmodule