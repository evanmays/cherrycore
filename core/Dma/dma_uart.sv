// when in doubt, play with this toy https://evanw.github.io/float-toy/
// Low performance DMA engine
// Only supports one direction at a time
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
        SEND_WRITE_COMMAND,
        SEND_WRITE_ADDR,
        SEND_BYTES,
        SEND_FINISH,

        // read_cherry_float()
        SEND_READ_COMMAND,
        SEND_READ_ADDR,
        RECV_BYTES,
        RECV_FINISH,

        // end
        FINISH
    } S;

// cisa_mem_write
reg [7:0]   uart_tx_data;
reg         uart_tx_en;
wire        uart_tx_busy;
reg [4*4*18-1:0] send_buffer;

// cisa_mem_read
reg [4*4*18-1:0]    recv_buffer;
dma_stage_2_instr   temp_instr;
wire                uart_rx_valid;
wire [7:0]          uart_rx_data;

// cisa_mem_*
reg [15:0]  addr;
reg [5:0] bytes_counter; // used for send and receive bytes. should max out at 36 bytes
logic uart_tx_busy_truth;
// I'm not sure why i need this uart_tx_busy_truth but either one of two reasons
// 1) my uart module won't let me send out a uart the cycle after uart_tx_busy true even though the spec allows this with the 1 stop bit
// 2) the busy is registering at the wrong time
assign uart_tx_busy_truth = uart_tx_en | uart_tx_busy;

always_ff @(posedge clk) begin
    uart_tx_en      <= 0;
    case (S)
        IDLE: begin
            cache_write_port <= 0; // for mem_read // just override write enable to save power // reset here instead of finish state because when dma in finish state dcache still frozen. if you reset in finish state, dcache never knew the instruction existed.
            if (instr.raw_instr_data.valid) begin
                busy    <= 1;
                addr    <= instr.raw_instr_data.main_mem_addr;
                if (instr.raw_instr_data.mem_we) begin
                    S           <= SEND_WRITE_COMMAND;
                    send_buffer <= instr.dat;
                end else begin
                    S           <= SEND_READ_COMMAND;
                    temp_instr  <= instr;
                end
            end         
        end
        //
        // def read_cherry_float(f, addr):
        //
        SEND_READ_COMMAND: if (!uart_tx_busy_truth) begin
            uart_tx_en      <= 1;
            uart_tx_data    <= 8'd2;
            S <= SEND_READ_ADDR;
            bytes_counter <= 0;
        end
        SEND_READ_ADDR: if (!uart_tx_busy_truth) begin
            bytes_counter <= bytes_counter + 1;
            uart_tx_en      <= 1;
            uart_tx_data    <= (bytes_counter == 0) ? addr[15:8] : addr[7:0];
            if (bytes_counter == 1) begin
                S <= RECV_BYTES;
                bytes_counter <= 0;
            end
        end
        RECV_BYTES: if (uart_rx_valid) begin
            bytes_counter <= bytes_counter + 1;
            recv_buffer <= {recv_buffer[4*4*18-1-8:0], uart_rx_data};
            if (bytes_counter == 35) // read 36 bytes
                S <= RECV_FINISH;
        end
        RECV_FINISH: begin
            cache_write_port.raw_instr_data <= temp_instr.raw_instr_data;
            cache_write_port.dat            <= recv_buffer;
            S <= FINISH;
        end
        //
        // def write_cherry_float(f, addr):
        //
        SEND_WRITE_COMMAND: if (!uart_tx_busy_truth) begin
            uart_tx_en      <= 1;
            uart_tx_data    <= 8'd3;
            S               <= SEND_WRITE_ADDR;
            bytes_counter <= 0;
        end
        SEND_WRITE_ADDR: if(!uart_tx_busy_truth) begin
            bytes_counter <= bytes_counter + 1;
            uart_tx_en      <= 1;
            uart_tx_data    <= (bytes_counter == 0) ? addr[15:8] : addr[7:0];
            if (bytes_counter == 1) begin
                S <= SEND_BYTES;
                bytes_counter <= 0;
            end
        end
        SEND_BYTES: if (!uart_tx_busy_truth) begin
            bytes_counter   <= bytes_counter + 1;
            uart_tx_en      <= 1;
            uart_tx_data    <= send_buffer[4*4*18-1 -: 8];
            send_buffer     <= send_buffer << 8;
            if (bytes_counter == 35) // send 36 bytes
                S <= SEND_FINISH;
        end
        SEND_FINISH: if (!uart_tx_busy_truth) begin
            S <= FINISH;
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