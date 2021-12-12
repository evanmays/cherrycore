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
  output logic is_new_superscalar_group
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
always @(posedge clk) begin
  if (reset) begin
    head <= 0;
    tail <= 0;
    varray_len <= 0;
    is_new_superscalar_group <= 1;
  end else begin
    if (we) begin
      mem_varr_pos_start[head]      <= write_addr;
      mem_varr_pos_end_offset[head] <= write_addr_len;
      mem_varr_dat[head]            <= dat_w;

      head <= head + 1; // % QUEUE_LENGTH
      varray_len <= write_addr + write_addr_len;
    end
    if (re) begin
      // assert (read_addr < varray_len);
      if (queue_size != 0 && read_addr + 1 == mem_varr_pos_start[tail] + mem_varr_pos_end_offset[tail]) begin // how does this behave when value at memory location tail is X
        tail <= tail + 1;
      end
      is_new_superscalar_group <= (read_addr < mem_varr_pos_start[tail] || read_addr + 1 == mem_varr_pos_start[tail] + mem_varr_pos_end_offset[tail]);
    end
  end
end
// Combinatorial so we can do some post procesing before clock period ends in instruction queue module
always @(*)
  if (re) begin
    // assert (read_addr < varray_len);
    if (queue_size == 0 || read_addr < mem_varr_pos_start[tail]) begin // how does this behave in hardware if  mem_varr_pos_start[tail] is X. We have that case to check for when user is reading in between entries. But maybe maybe should be read_addr < varray_len. not sure if that stops propagation or not
      dat_r <= 0;
    end else begin
      dat_r <= mem_varr_dat[tail];
    end
  end else begin
    dat_r <= 0;
  end
endmodule