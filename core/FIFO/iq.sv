// There's this idea of the superscalar instruction queue
// You push multiple instructions at a time to the different
// instruction pipelines. Then you pop one instr from each pipeleine at a time.
// Each instruction pipeleine's queue is represented by a virtual array with 65536 elements.
// When the virtual arrays are full. we need to refresh our position in the virtual array
// the virtual arrays are so sparse and we only do accesses in montoonically increasing so we use a queue to represent them
// No BRAMs, just distirbuted ram. Under 200 LUT.

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
  input logic [LOG_SUPERSCALAR_WIDTH-1:0]       copy_count,
  input logic [17:0]                            cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr,
  input logic [0:9]                             in_arith_instr,
  input logic [0:8]                             in_ram_instr,
  input logic [0:9]                             in_ld_st_instr,
  output logic                                  needs_reset
);

localparam [3:0] LOG_SUPERSCALAR_WIDTH = 4;
localparam [3:0] SUPERSCALAR_WIDTH = 16;
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

reg varray_we [0:2];
// varray #(.VIRTUAL_ELEMENT_WIDTH(0)) cache_varray (
//   .clk(clk),
//   .reset(reset),

//   .we(in_instr_type == INSTR_TYPE_LOAD_STORE),
//   .write_addr(insert_varray_pos),
//   .write_addr_len(copy_count),
//   .dat_w({in_ld_st_instr, cache_addr, d_cache_addr}),

//   .re(re),
//   .read_addr(varray_read_pos),
//   .dat_r(out_cache_instr)
// );
// varray #(.VIRTUAL_ELEMENT_WIDTH(0)) dma_varray (
//   .clk(clk),
//   .reset(reset),

//   .we(in_instr_type == INSTR_TYPE_RAM),
//   .write_addr(insert_varray_pos),
//   .write_addr_len(copy_count),
//   .dat_w({in_ram_instr, main_mem_addr, d_main_mem_addr}),

//   .re(re),
//   .read_addr(varray_read_pos),
//   .dat_r(out_dma_instr)
// );

varray #(.VIRTUAL_ELEMENT_WIDTH(10)) arith_varray (
  .clk(clk),
  .reset(reset),

  .we(in_instr_type == INSTR_TYPE_ARITHMETIC),
  .write_addr(insert_varray_pos),
  .write_addr_len(copy_count),
  .dat_w(in_arith_instr),

  .re(re),
  .read_addr(varray_read_pos),
  .dat_r(out_math_instr)
);

endmodule
