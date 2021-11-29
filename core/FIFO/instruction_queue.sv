//
// Macros to make code easier to read
//

`define next_spot_in_queue_define \
  reg [9:0] next_spot_in_dma_instr_queue; \
  reg [9:0] next_spot_in_regfile_instr_queue; \
  reg [9:0] next_spot_in_arith_instr_queue;

`define next_spot_in_queue_reset \
  next_spot_in_dma_instr_queue <= 0; \
  next_spot_in_regfile_instr_queue <= 0; \
  next_spot_in_arith_instr_queue <= 0;

`define next_spot_in_queue_set(instr_type, val) \
  case (instr_type) \
    INSTR_TYPE_RAM: next_spot_in_dma_instr_queue <= next_spot_in_cur_instr_queue; \
    INSTR_TYPE_LOAD_STORE: next_spot_in_regfile_instr_queue <= next_spot_in_cur_instr_queue; \
    INSTR_TYPE_ARITHMETIC: next_spot_in_arith_instr_queue <= next_spot_in_cur_instr_queue; \
  endcase
`define next_spot_in_queue_get(instr_type) \
  instr_type == INSTR_TYPE_RAM ? next_spot_in_dma_instr_queue : \
  instr_type == INSTR_TYPE_LOAD_STORE ? next_spot_in_regfile_instr_queue: \
  /* instr_type == INSTR_TYPE_ARITHMETIC */ next_spot_in_arith_instr_queue;

`define queue_position_when_done_define \
  reg [9:0] dma_instr_queue_position_when_done; \
  reg [9:0] regfile_instr_queue_position_when_done; \
  reg [9:0] arith_instr_queue_position_when_done;

`define queue_position_when_done_reset \
  dma_instr_queue_position_when_done <= 0; \
  regfile_instr_queue_position_when_done <= 0; \
  arith_instr_queue_position_when_done <= 0;

`define queue_position_when_done_set(instr_type, val) \
  case (instr_type) \
    INSTR_TYPE_RAM: dma_instr_queue_position_when_done <= insert_spot + RAM_INSTRUCTION_LATENCY; \
    INSTR_TYPE_LOAD_STORE: regfile_instr_queue_position_when_done <= insert_spot + REGFILE_INSTRUCTION_LATENCY; \
    INSTR_TYPE_ARITHMETIC: arith_instr_queue_position_when_done <= insert_spot + ARITH_INSTRUCTION_LATENCY; \
  endcase

`define queue_position_when_done_get(instr_type) \
  instr_type == INSTR_TYPE_RAM ? dma_instr_queue_position_when_done : \
  instr_type == INSTR_TYPE_LOAD_STORE ? regfile_instr_queue_position_when_done: \
  /* instr_type == INSTR_TYPE_ARITHMETIC */ arith_instr_queue_position_when_done;

//
// Actual implementation
//
// After 1,000 inserts the queue breaks
module instruction_queue #(parameter LOG_SUPERSCALAR_WIDTH=3)(
  input                         reset,
  input                         clk,

  // Pop
  input                         re,
  output dma_instruction        dma_instr,        // todo, adjust the input format to match this
  output arithmetic_instruction arithmetic_instr, // todo, adjust the input format to match this
  output regfile_instruction    cache_instr,      // todo, adjust the input format to match this
  output wire                   empty,            // todo

  // Push
  input                                 we,
  input [1:0]               in_instr_type,
  input [LOG_SUPERSCALAR_WIDTH:0]       copy_count,
  input [17:0] cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr,
  input [0:13] in_arith_instr,
  input [0:8]  in_ram_instr,
  input [0:9]  in_ld_st_instr
);

localparam SUPERSCALAR_WIDTH = (1 << LOG_SUPERSCALAR_WIDTH);
localparam RAM_INSTRUCTION_LATENCY = 2;
localparam REGFILE_INSTRUCTION_LATENCY = 3;
localparam ARITH_INSTRUCTION_LATENCY = 6;
reg [9:0] dma_queue [21:0];
reg [9:0] cache_queue [16:0];
reg [9:0] arith_queue [4:0];
reg [1:0] prev_instr_type;
`next_spot_in_queue_define
`queue_position_when_done_define
wire [9:0] prev_instr_queue_position_when_done = `queue_position_when_done_get(prev_instr_type)
wire [9:0] cur_instr_queue_next_available_spot = `next_spot_in_queue_get(in_instr_type)
wire [9:0] insert_spot = max(prev_instr_queue_position_when_done, cur_instr_queue_next_available_spot);
wire [9:0] next_spot_in_cur_instr_queue = insert_spot + SUPERSCALAR_WIDTH; // would be better if this is + copy_count?
reg [9:0] read_pos;

//
// Write (Push)
//
for(genvar i = 0; i < SUPERSCALAR_WIDTH; i++) begin
  always @(posedge clk) begin
    if (we) begin
      if (in_instr_type === INSTR_TYPE_RAM        && i <= copy_count)   dma_queue[insert_spot + i] <= in_ram_instr;// need to do cur address and daddr to be more efficient
        // should i just always set these values and instead set {dma_instr, 0  <= copy_count}? that way we know if its valid or not.
      if (in_instr_type === INSTR_TYPE_LOAD_STORE && i <= copy_count) cache_queue[insert_spot + i] <= in_ld_st_instr;  // need to do cur address and daddr to be more efficient
      if (in_instr_type === INSTR_TYPE_ARITHMETIC && i <= copy_count) arith_queue[insert_spot + i] <= in_arith_instr;
    end
  end
end

always @(posedge clk) begin
  if (we) begin
    prev_instr_type <= in_instr_type;
    `next_spot_in_queue_set(in_instr_type, next_spot_in_cur_instr_queue)
    `queue_position_when_done_set(in_instr_type, insert_spot)
  end
  if (reset) begin
    prev_instr_type <= INSTR_TYPE_LOAD_STORE;
    `next_spot_in_queue_reset
    `queue_position_when_done_reset
  end
end

//
// Read (Pop)
//
always @(posedge clk) begin
  if (re) begin
    read_pos <= read_pos + 1;
    dma_instr <= dma_queue[read_pos]; // need checks for if this position is really empty
    cache_instr <= cache_queue[read_pos];
    arithmetic_instr <= arith_queue[read_pos];
  end
  if (reset) begin
    read_pos <= 0;
    dma_instr <= 0;
    cache_instr <= 0;
    arithmetic_instr <= 0;
  end
end
function [9:0] max;
	input [9:0] a, b;
	begin
    max = a > b ? a : b;
	end
endfunction
endmodule