// There's this idea of the superscalar instruction queue
// You push multiple instructions at a time to the different
// instruction pipelines. Then you pop one instr from each pipeleine at a time.
// Each instruction pipeleine's queue is represented by a virtual array with 65536 elements.
// When the virtual arrays are full. we need to refresh our position in the virtual array
// the virtual arrays are so sparse and we only do accesses in montoonically increasing so we use a queue to represent them
// Under 500 LUTs

// One cycle latency for all output ports.
module instruction_queue (
  input                         reset,
  input                         clk,

  // Pop
  input  logic                  re,
  output dma_instruction        out_dma_instr,
  output math_instr             out_math_instr,
  output regfile_instruction    out_cache_instr,
  output logic                   empty,

  // Push
  input logic                                   we,
  input logic [1:0]                             in_instr_type,
  input logic [LOG_SUPERSCALAR_WIDTH:0]         copy_count,
  input logic [10:0]                            cache_addr, d_cache_addr,
  input logic [6:0]                             main_mem_addr, d_main_mem_addr,
  input logic [0:8]                             in_arith_instr,
  input logic [0:2]                             in_ram_instr,
  input logic [0:6]                             in_ld_st_instr,
  output logic                                  needs_reset
);

localparam [3:0] LOG_SUPERSCALAR_WIDTH = 4;
localparam [4:0] SUPERSCALAR_WIDTH = 16;
localparam [3:0] DMA_INSTRUCTION_LATENCY = 2;
localparam REGFILE_INSTRUCTION_LATENCY = 3;
localparam ARITH_INSTRUCTION_LATENCY = 10;
localparam VARRAY_POS_BITS = 16;

reg [1:0]  prev_instr_type;
reg [VARRAY_POS_BITS-1:0] next_free_spot_in_varray [0:2];
reg [VARRAY_POS_BITS-1:0] varray_pos_when_done [0:2];

wire [VARRAY_POS_BITS-1:0] insert_varray_pos = max(
                                                varray_pos_when_done[prev_instr_type],
                                                next_free_spot_in_varray[in_instr_type],
                                                varray_read_pos
                                              );
reg [VARRAY_POS_BITS-1:0] varray_read_pos;

assign needs_reset = varray_read_pos == {16{1'b1}};

always @(posedge clk) begin
  if (reset) begin
    prev_instr_type <= INSTR_TYPE_LOAD_STORE;
    next_free_spot_in_varray[INSTR_TYPE_RAM] <= 0;
    next_free_spot_in_varray[INSTR_TYPE_LOAD_STORE] <= 0;
    next_free_spot_in_varray[INSTR_TYPE_ARITHMETIC] <= 0;
    varray_pos_when_done[INSTR_TYPE_RAM] <= 0;
    varray_pos_when_done[INSTR_TYPE_LOAD_STORE] <= 0;
    varray_pos_when_done[INSTR_TYPE_ARITHMETIC] <= 0;
    varray_read_pos <= 0;
  end else begin
    if (we) begin
      varray_pos_when_done[in_instr_type] <= insert_varray_pos + latency(in_instr_type);
      next_free_spot_in_varray[in_instr_type] <= insert_varray_pos + SUPERSCALAR_WIDTH; // would be better if this is + copy_count?
      prev_instr_type <= in_instr_type;
    end
    if (re)
      varray_read_pos <= varray_read_pos + 1;
  end
end
function [VARRAY_POS_BITS-1:0] max;
	input [VARRAY_POS_BITS-1:0] a, b, c;
	begin
    max = a > b ? (a > c ? a : c) : (b > c ? b : c);
	end
endfunction

function [3:0] latency;
  input [1:0] instr_type;
  begin
    case (instr_type)
      INSTR_TYPE_RAM: begin
        latency = DMA_INSTRUCTION_LATENCY;
      end
      INSTR_TYPE_LOAD_STORE: begin
        latency = REGFILE_INSTRUCTION_LATENCY;
      end
      INSTR_TYPE_ARITHMETIC: begin
        latency = ARITH_INSTRUCTION_LATENCY;
      end
    endcase
  end
endfunction


wire [0:29] cache_varray_dat_r;
wire        cache_varray_is_new_superscalar_group;
varray #(.VIRTUAL_ELEMENT_WIDTH(30)) cache_varray (
  .clk(clk),
  .reset(reset),

  .we(we && in_instr_type == INSTR_TYPE_LOAD_STORE),
  .write_addr(insert_varray_pos),
  .write_addr_len(copy_count),
  .dat_w({1'b1, in_ld_st_instr, cache_addr, d_cache_addr}),

  .re(re),
  .read_addr(varray_read_pos),
  .dat_r(cache_varray_dat_r),
  .is_new_superscalar_group(cache_varray_is_new_superscalar_group)
);

wire [0:39] dma_varray_dat_r;
wire        dma_varray_is_new_superscalar_group;
varray #(.VIRTUAL_ELEMENT_WIDTH(40)) dma_varray (
  .clk(clk),
  .reset(reset),

  .we(we && in_instr_type == INSTR_TYPE_RAM),
  .write_addr(insert_varray_pos),
  .write_addr_len(copy_count),
  .dat_w({1'b1, in_ram_instr[0], main_mem_addr, d_main_mem_addr, cache_addr, d_cache_addr, in_ram_instr[1:2]}),

  .re(re),
  .read_addr(varray_read_pos),
  .dat_r(dma_varray_dat_r),
  .is_new_superscalar_group(dma_varray_is_new_superscalar_group)
);

// Do some post processing on the varray elements
// to reconstruct the actual addresses
always @(posedge clk) begin
  // Math Instruction Out
  out_math_instr <= math_varray_dat_r;

  // Cache Instruction Out
  //{in_ld_st_instr, cache_addr, d_cache_addr}
  out_cache_instr.valid <= cache_varray_dat_r[0];

  out_cache_instr.is_load <= cache_varray_dat_r[1];
  out_cache_instr.cache_slot <= cache_varray_dat_r[2:3];
  out_cache_instr.regfile_reg <= cache_varray_dat_r[4:5];
  // out_cache_instr.zero_flag <= cache_varray_dat_r[6]; // TODO
  // out_cache_instr.skip_flag <= cache_varray_dat_r[7]; // TODO
  if (cache_varray_is_new_superscalar_group)
    out_cache_instr.cache_addr <= cache_varray_dat_r[8 +: 11];
  else
    out_cache_instr.cache_addr <= out_cache_instr.cache_addr + cache_varray_dat_r[19 +: 11];

  // DMA Instruction Out
  out_dma_instr.valid <= dma_varray_dat_r[0];
  out_dma_instr.mem_we <= dma_varray_dat_r[1];
  out_dma_instr.cache_slot <= dma_varray_dat_r[38:39];
  if (dma_varray_is_new_superscalar_group) begin
    out_dma_instr.main_mem_addr <= dma_varray_dat_r[2 +: 7];
    out_dma_instr.cache_addr    <= dma_varray_dat_r[16 +: 11];
  end else begin
    out_dma_instr.main_mem_addr <= out_dma_instr.main_mem_addr + dma_varray_dat_r[9 +: 7];
    out_dma_instr.cache_addr    <= out_dma_instr.cache_addr + dma_varray_dat_r[27 +: 11];
  end

  if (reset) begin
    out_math_instr <= 0;
    out_dma_instr <= 0;
    out_cache_instr <= 0;
  end
end

wire [0:9] math_varray_dat_r;
varray #(.VIRTUAL_ELEMENT_WIDTH(10)) math_varray (
  .clk(clk),
  .reset(reset),

  .we(we && in_instr_type == INSTR_TYPE_ARITHMETIC),
  .write_addr(insert_varray_pos),
  .write_addr_len(copy_count),
  .dat_w({1'b1, in_arith_instr}),

  .re(re),
  .read_addr(varray_read_pos),
  .dat_r(math_varray_dat_r)
);

endmodule
