module top #(parameter CLK_HZ=50000000) (
input               clk     , // Top level system clock input.
input               sw_0 , // reset switch
input   wire        uart_rxd, // UART Recieve pin.
output  wire        uart_txd,  // UART transmit pin.
output  wire [7:0]  led
);
wire                freeze;
assign freeze = dma_busy;
assign led[1] = freeze;
//assign led[5] = queue_empty;
assign led[2] = dma_stage_3_dcache_write.raw_instr_data.valid;
wire                  queue_empty;

dma_stage_1_instr   dma_stage_1_dcache_read;
dma_stage_2_instr   dma_stage_2_execute;
dma_stage_3_instr   dma_stage_3_dcache_write;

wire          dma_busy;
wire q_re;
assign q_re = !queue_empty & !freeze; // do we lose data?
fake_queue queue (
.clk(clk),
.reset(sw_0),
.dma_instr(dma_stage_1_dcache_read),
.empty(queue_empty),
.re(q_re)
);

dma_uart dma (
.clk(clk),
.reset(sw_0),
.instr(dma_stage_2_execute),
.busy(dma_busy),
// .freeze(freeze), jk, no one can freeze the DMA

// command cache signals
.cache_write_port(dma_stage_3_dcache_write),

// board pins
.uart_rxd(uart_rxd), // UART Recieve pin.
.uart_txd(uart_txd)  // UART transmit pin.

);

dcache dcache (
.clk(clk),
.dma_read_port_in   (dma_stage_1_dcache_read),
.dma_read_port_out  (dma_stage_2_execute),
.dma_write_port     (dma_stage_3_dcache_write),
.reset(sw_0),
.freeze(freeze)
);

endmodule