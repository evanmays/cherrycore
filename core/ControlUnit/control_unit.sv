// Superscalar Control Unit. It's a slow state machine, but it pushes about 9 IPC to instruction queue. Other end of queue pops at most 3 IPC.
// Loop instructions are completely retired by the control unit!
// pull from program execution queue
// load ro_data from program header cache
// while True:
//   decode instruction from program instruction cache at pc
//   if loop instruction
//     if start loop instruction
//        create new loop
//     else
//        # end loop instruction
// 	      update loop variable
// 	   update APU
// 	   continue
// 	 elif dma instruction
// 		 initiate prefetch
// 	 calculate instruction queue copy amount and put in queue (also get the apu values if needed)
//   update pc and break loop if pc > program_instr_count
// notify host computer of completion
module control_unit #(parameter LOG_SUPERSCALAR_WIDTH=3)(
  input               clk,
  input               reset,
  input       [0:15]  raw_instruction,
  output reg  [15:0]  pc
);
enum {IDLE, PREPARE_PROGRAM, DECODE, START_NEW_LOOP, INCREMENT_LOOP, UPDATE_APU, INIT_PREFETCH, INSERT_TO_QUEUE, UPDATE_PC, FINISH_PROGRAM} S;
e_instr_type instr_type;

// Info about current program
reg [15:0]  program_end_pc;
reg [6:0]   program_header_cache_addr;
reg [0:24*8-1] loop_ro_data;

localparam SUPERSCALAR_WIDTH = (1 << LOG_SUPERSCALAR_WIDTH);

// Loop variables
localparam LOG_LOOP_CNT = 3;
localparam LOOP_CNT = (1 << LOG_LOOP_CNT);
reg signed [LOG_LOOP_CNT:0] loop_depth; // -1 is empty
reg [LOOP_CNT] [17:0] loop_value;
reg [LOOP_CNT] [17:0] loop_stack_total_iterations;
reg [LOOP_CNT] [7:0] loop_stack_jump_amount;
reg [LOOP_CNT] loop_is_independent;
wire loop_depth_plus_one = loop_depth + 1;
reg [7:0] jump_amount;
wire [17:0] loop_remaining_iterations = loop_stack_total_iterations[loop_depth] - loop_value[loop_depth];

// APU
parameter LOG_APU_CNT = 3;
parameter APU_CNT = (1 << LOG_APU_CNT);
reg [LOG_LOOP_CNT-1:0] apu_in_loop_var; // input set by loop update FSM step
reg [17:0] apu_in_di; // input set by loop update FSM step
reg [APU_CNT] [18*9-1:0] apu_linear_formulas; // ro_data: each formula has 8 coefficients and 1 constant
reg [APU_CNT] [17:0] apu_address_registers; // current data

always @(posedge clk) begin
  case (S)
    IDLE: begin
      S <= PREPARE_PROGRAM;
    end
    PREPARE_PROGRAM: begin
      pc <= 0;
      program_end_pc <= 10;
      S <= DECODE;
      // setup apu_address_registers to constant values
      // load loop_ro_data <= 0;
    end
    DECODE: begin
      
      case (instr_type)
        INSTR_TYPE_LOOP: S <= loop_instr.is_new_loop ? START_NEW_LOOP : INCREMENT_LOOP;
        INSTR_TYPE_RAM: S <= INSERT_TO_QUEUE;// INIT_PREFETCH;
        default: S <= INSERT_TO_QUEUE;
      endcase
    end
    START_NEW_LOOP: begin
      loop_value[loop_depth_plus_one] <= 0;
      loop_depth <= loop_depth_plus_one;
      loop_is_independent[loop_depth_plus_one] <= loop_instr.is_independent;
      S <= UPDATE_APU;
    end
    INCREMENT_LOOP: begin
      loop_value[loop_depth]  <= loop_value[loop_depth] + (loop_is_independent[loop_depth] ? (loop_remaining_iterations <= SUPERSCALAR_WIDTH ? loop_remaining_iterations : SUPERSCALAR_WIDTH) : 1);
      apu_in_loop_var <= loop_depth;
      
      if (loop_remaining_iterations <= SUPERSCALAR_WIDTH) begin
        apu_in_di <= loop_stack_total_iterations[loop_depth];
      end else begin
        apu_in_di                  <=                         (loop_is_independent[loop_depth] ? (loop_remaining_iterations <= SUPERSCALAR_WIDTH ? loop_remaining_iterations : SUPERSCALAR_WIDTH) : 1);
        jump_amount <= loop_stack_jump_amount[loop_depth];
      end
      S <= UPDATE_APU;
    end
    UPDATE_APU: begin
      for (integer k = 0; k < LOOP_CNT ; k = k + 1) begin // will this synthesize properly? do we need to use macros?
        apu_address_registers[k] <= apu_in_di * daddr_di(apu_linear_formulas[k], apu_in_loop_var);
      end
      S <= UPDATE_PC;
    end
    INIT_PREFETCH: begin
      // currently unsupported
      S <= INSERT_TO_QUEUE;
    end
    INSERT_TO_QUEUE: begin
      S <= UPDATE_PC;
    end
    UPDATE_PC: begin
      pc <= pc + 1 - jump_amount;
      jump_amount <= 0;
      S <= pc >= program_end_pc ? FINISH_PROGRAM
                                : DECODE;
    end
    FINISH_PROGRAM: begin
      S <= IDLE;
    end
  endcase
  if (reset) begin
    pc <= 0;
    program_end_pc <= 0;
    loop_ro_data <= 0;
    program_header_cache_addr <= 0;
    loop_depth <= -1;
    loop_value <= 0;
    loop_stack_jump_amount <= 0;
    jump_amount <= 0;
    apu_in_loop_var <= 0;
    apu_in_di <= 0;
    apu_linear_formulas <= 0;
    apu_address_registers <= 0;
    
  end
end


function [17:0] constant;
	input [18*9-1:0] linear_formula;
	begin
		constant = linear_formula[144 +: 18];
	end
endfunction
function [17:0] daddr_di;
	input [18*9-1:0] linear_formula;
  input [LOG_LOOP_CNT-1:0] loop_var;
	begin
    // check if synthesized right, might need big switch case
		daddr_di = linear_formula[loop_var*18 +: 18];
	end
endfunction

decoded_load_store_instruction ld_st_instr;
decoded_ram_instruction ram_instr;
decoded_arithmetic_instruction arith_instr;
decoded_loop_instruction loop_instr;
e_instr_type instruction_type;
decoder decoder(
// in
.loop_ro_data(loop_ro_data),
.raw_instruction(raw_instruction),
// out
.ld_st_instr(ld_st_instr),
.ram_instr(ram_instr),
.arith_instr(arith_instr),
.loop_instr(loop_instr),
.instruction_type(instruction_type)
);
endmodule


