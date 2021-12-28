// Can push up to 4 elements per cycle
// Can pop up to 1 element per cycle
// We just push the formula out=addr + i * d_addr
// Then when we pop, we pop an out for i from 0 to 3.
module prefetch_initiate_superscalar_fifo #(parameter LINE=18)(
  input clk,
  input reset,
  input re,
  input we,
  input initiate_prefetch_command dat_w,
  output logic [LINE-1:0] dat_r,
  output logic full,
  output logic emptyn
);
  localparam COPY_COUNT_WIDTH = 5;
  // mem[tail] is in the list. mem[head] is next position to put something
  initiate_prefetch_command mem [0:63];
  reg [5:0] head, tail;
  reg [COPY_COUNT_WIDTH-1:0] read_counter;
  wire [5:0] size = head >= tail ? head - tail : 63 - tail + head + 1;
  assign full = size == 60; // makes life easier
  assign emptyn = size > 0;
  always @(posedge clk) begin
    if (we && !full) begin
      assert(dat_w.copy_count > 0 && dat_w.copy_count <= 16);
      mem[head] <= dat_w;
      head <= head + 1; // % 64
    end
    if (re && emptyn) begin
      read_counter <= read_counter + 1;
      if (read_counter + 1 == mem[tail].copy_count) begin
        tail <= tail + 1;
        read_counter <= 0;
      end
      dat_r <= read_counter == 0
                ? mem[tail].addr
                : dat_r + mem[tail].d_addr;
    end
    if (reset) begin
      head <= 0;
      tail <= 0;
      read_counter <= 0;
      dat_r <= 0;
    end
  end
 endmodule