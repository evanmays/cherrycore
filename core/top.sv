module top #(parameter CLK_HZ=50000000) (
input               clk     , // Top level system clock input.
input               sw_0 , // reset switch
input   wire        uart_rxd, // UART Recieve pin.
output  wire        uart_txd,  // UART transmit pin.
output  wire [7:0]  led
);
wire                freeze;
assign freeze = queue_empty | dma_busy;
assign led[7] = freeze;
// assign led[5] = queue_empty;
assign led[0] = dma_busy;

wire                queue_empty;
wire [21:0]         dma_instr;
reg                 re;

wire [6:0]    addr;
wire [17:0]   cherry_float_w;
wire          dma_we;
wire [17:0]   cherry_float_r;
wire          dma_re;
wire          dma_busy;
assign addr           = 7'd120;
assign cherry_float_w = cherry_float_r; // write to dma the most recently read value from dma. Requires a write to occur after atleast 1 read
assign dma_we         = !freeze & dma_instr[21] &  dma_instr[20]; // not froze, dma instruction non empty, dma instrcuton is a write
assign dma_re         = !freeze & dma_instr[21] & !dma_instr[20]; // not froze, dma instruction non empty, dma instrcuton is a read


// stop reading when frozen
assign re = sw_0 ? 1 : !freeze;
// always @(posedge clk) begin
//   if (sw_0) begin
//     re <= 1;
//   end else begin
//     re <= !freeze;
//   end
// end

fake_queue queue (
.clk(clk),
.reset(sw_0),
.dma_instr(dma_instr),
.empty(queue_empty),
.re(re)
);

dma_uart dma (
.clk(clk),
.reset(sw_0),
.dma_dat_addr(addr),
.dma_dat_w(cherry_float_w),
.we(dma_we),
.dma_dat_r(cherry_float_r),
.re(dma_re),
.busy(dma_busy),

// command cache signals
.cache_cmd_we(cache_cmd_we),



// board pins
.uart_rxd(uart_rxd), // UART Recieve pin.
.uart_txd(uart_txd)  // UART transmit pin.

);

endmodule