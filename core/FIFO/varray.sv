// 65536 element array. write_addr and read_addr must be monotonically increasing
// Internally its just a small queue

module varray (
  input clk,
  input reset,
  input we,
  input [VIRTUAL_ADDR_BITS-1:0] write_addr,
  input [4:0] write_addr_len, // writes to arr[write_addr +: write_addr_len]
  input [0:VIRTUAL_ELEMENT_WIDTH-1] dat_w,
  input logic re,
  input [VIRTUAL_ADDR_BITS-1:0] read_addr,
  output logic [0:VIRTUAL_ELEMENT_WIDTH-1] dat_r,
  output logic [VIRTUAL_ADDR_BITS-1:0] varray_len,
  output logic is_new_superscalar_group,
  output logic queue_almost_full
);
parameter VIRTUAL_ELEMENT_WIDTH = 18;
parameter VIRTUAL_ADDR_BITS = 16;

localparam LOG_QUEUE_LENGTH = 6;
localparam QUEUE_LENGTH = (1 << LOG_QUEUE_LENGTH);
logic [VIRTUAL_ADDR_BITS-1:0]  mem_varr_pos_start [0:QUEUE_LENGTH-1];
logic [4:0]   mem_varr_pos_end_offset [0:QUEUE_LENGTH-1];
logic [0:VIRTUAL_ELEMENT_WIDTH-1]  mem_varr_dat [0:QUEUE_LENGTH-1];
logic [LOG_QUEUE_LENGTH-1:0] head, tail;
wire [LOG_QUEUE_LENGTH-1:0] queue_size = head >= tail ? head - tail : QUEUE_LENGTH - 1 - tail + head;
assign queue_almost_full = queue_size > QUEUE_LENGTH - 3; // fix later: can probably do minus 1?
always @(posedge clk) begin
  if (reset) begin
    head <= 0;
    tail <= 0;
    varray_len <= 0;
    is_new_superscalar_group <= 1;
  end else begin
    if (we) begin
      if (VIRTUAL_ELEMENT_WIDTH==40) $display("Writing to varray at head %d with virtual pos %d and dat %b", head, write_addr, dat_w);
      mem_varr_pos_start[head]      <= write_addr;
      mem_varr_pos_end_offset[head] <= write_addr_len;
      mem_varr_dat[head]            <= dat_w;

      head <= head + 1; // % QUEUE_LENGTH
      // verilator lint_off WIDTH
      varray_len <= write_addr + write_addr_len;
      // verilator lint_on WIDTH
    end
    if (re) begin
      // assert (read_addr < varray_len);
      // if (VIRTUAL_ELEMENT_WIDTH==40 && re && read_addr >= mem_varr_pos_start[tail] && read_addr < mem_varr_pos_start[tail] + mem_varr_pos_end_offset[tail]) $display("deep %x %x %x %b %b", $past(re), $past(read_addr >= mem_varr_pos_start[tail]), $past(read_addr < mem_varr_pos_start[tail] + mem_varr_pos_end_offset[tail]), dat_r, $past(dat_r));
      if (queue_size != 0 && read_addr + 1 == /*verilator lint_off WIDTH */ mem_varr_pos_start[tail] + mem_varr_pos_end_offset[tail] /*verilator lint_on WIDTH */) begin // how does this behave when value at memory location tail is X
        tail <= tail + 1;
      end
      // if (VIRTUAL_ELEMENT_WIDTH==40) $display("read addr %d pos start tail %d", read_addr,  mem_varr_pos_start[tail]);
      // verilator lint_off WIDTH
      is_new_superscalar_group <= (read_addr < mem_varr_pos_start[tail] || read_addr + 1 == mem_varr_pos_start[tail] + mem_varr_pos_end_offset[tail]);
      // verilator lint_on WIDTH
    end
  end
end
// Combinatorial so we can do some post procesing before clock period ends in instruction queue module
// assert ( if re then read_addr < varray_len);
// verilator lint_off WIDTH
assign dat_r = (read_addr >= mem_varr_pos_start[tail] && read_addr < mem_varr_pos_start[tail] + mem_varr_pos_end_offset[tail]) ? mem_varr_dat[tail] : 0; // can be invalid if we had recently reset and old data is still in mem_varr_*
// verilator lint_on WIDTH
// how does this behave in hardware if  mem_varr_pos_start[tail] is X. We have that case to check for when user is reading in between entries. But maybe maybe should be read_addr < varray_len. not sure if that stops propagation or not

`ifdef FORMAL
  initial restrict(reset);
  initial last_read_addr = -1;
  always @($global_clock) begin
    restrict(clk == !$past(clk));
    if (!$rose(clk)) begin
      assume($stable(reset));
      assume($stable(we));
      assume($stable(write_addr));
      assume($stable(write_addr_len));
      assume($stable(dat_w));
      assume($stable(re));
      assume($stable(read_addr));
    end
  end
  reg [15:0] last_write_addr;
  reg [4:0] last_write_addr_len;
  initial begin
    f_past_valid = 1'b0;
    last_write_addr = 0;
    last_write_addr_len = 0;
  end
  always @(posedge clk) begin
    assume(write_addr_len > 0 && write_addr_len <= 16);
  f_past_valid <= 1'b1;
  if (f_past_valid) begin
    if ($past(varray_len) > 65535 - 16) begin
      assume(!we);
      assume($stable(write_addr));
      assume($stable(write_addr_len));
      if (!$past(reset)) assert($stable(varray_len));
    end
    if (we) begin
      assume(write_addr >= last_write_addr + last_write_addr_len);
      assume(write_addr <= 65535 - 16);
      last_write_addr <= write_addr;
      last_write_addr_len <= write_addr_len;
    end
    if (re) assume(read_addr >= $past(write_addr));
    if (re) begin
      assume(read_addr == last_read_addr + 1);
      last_read_addr <= read_addr;
    end
    if ($past(varray_len) == 0 && !$past(we)) assert(varray_len == 0);
    if ($past(reset)) assert(varray_len == 0);
    if (!$past(reset)) assert(varray_len >= $past(varray_len));
  end
  end
`endif
endmodule