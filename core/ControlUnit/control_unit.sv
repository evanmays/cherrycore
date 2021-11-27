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
  input  bit  [0:15]  raw_instruction, // using bit so we can cast raw_instruction[0:1] to instruction_type
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
reg [LOOP_CNT-1:0] loop_stack_value [17:0];
reg [LOOP_CNT-1:0] loop_stack_total_iterations [17:0];
reg [LOOP_CNT-1:0] loop_stack_jump_amount [7:0];
reg [LOOP_CNT-1:0] loop_is_independent;
wire loop_depth_plus_one = loop_depth + 1;
reg [7:0] jump_amount;
wire [17:0] loop_remaining_iterations = loop_stack_total_iterations[loop_depth] - loop_stack_value[loop_depth];

// APU
parameter LOG_APU_CNT = 3;
parameter APU_CNT = (1 << LOG_APU_CNT);
reg [LOG_LOOP_CNT-1:0] apu_in_loop_var; // input set by loop update FSM step
reg [17:0] apu_in_di; // input set by loop update FSM step
reg [APU_CNT-1:0] apu_linear_formulas [18*9-1:0]; // ro_data: each formula has 8 coefficients and 1 constant
reg [APU_CNT-1:0] apu_address_registers [17:0]; // current data
reg [LOG_APU_CNT-1:0] cache_apu, main_mem_apu;

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
      loop_stack_value[loop_depth_plus_one] <= 0;
      loop_depth <= loop_depth_plus_one;
      loop_is_independent[loop_depth_plus_one] <= loop_instr.is_independent;
      loop_stack_jump_amount[loop_depth_plus_one] <= loop_instr.jump_amount;
      loop_stack_total_iterations[loop_depth_plus_one] <= loop_instr.iteration_count;
      S <= UPDATE_APU;
    end
    INCREMENT_LOOP: begin
      loop_stack_value[loop_depth]  <= loop_stack_value[loop_depth] + (loop_is_independent[loop_depth] ? (loop_remaining_iterations <= SUPERSCALAR_WIDTH ? loop_remaining_iterations : SUPERSCALAR_WIDTH) : 1);
      apu_in_loop_var <= loop_depth;
      
      if (loop_remaining_iterations <= SUPERSCALAR_WIDTH) begin
        apu_in_di <= -1 * loop_stack_total_iterations[loop_depth];
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
      if (instruction_type == INSTR_TYPE_LOAD_STORE) begin
        cache_apu     <= apu_address_registers[ld_st_instr[11:13]];
      end
      if (instruction_type == INSTR_TYPE_RAM) begin
        cache_apu     <= apu_address_registers[ram_instr[1:3]];
        main_mem_apu  <= apu_address_registers[ram_instr[4:6]];
      end
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
    for (integer i=0; i<LOOP_CNT; i=i+1) begin
      loop_stack_value[i] <= 18'd0;
      loop_stack_total_iterations[i] <= 18'd0;
      loop_stack_jump_amount[i] <= 8'd0;
    end
    jump_amount <= 0;
    apu_in_loop_var <= 0;
    apu_in_di <= 0;
    for (integer i=0; i<APU_CNT; i=i+1) begin
      apu_address_registers[i] <= 18'd0;
      apu_linear_formulas[i] <= 162'd0;
    end
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

//
// Partial Decoder
//
e_instr_type instruction_type = raw_instruction[0:1] == 2'd0 ? INSTR_TYPE_LOAD_STORE : raw_instruction[0:1] == 2'd1 ? INSTR_TYPE_RAM : raw_instruction[0:1] == 2'd2 ? INSTR_TYPE_ARITHMETIC : INSTR_TYPE_LOOP; // iverilog doesn't support simple cast  e_instr_type'()
wire [0:13] arith_instr = raw_instruction[2:15];
wire [0:6]  ram_instr   = raw_instruction[2:8]; // 1 bit is_write, 6 bit 2 apus
wire [0:13] ld_st_instr = raw_instruction[2:15]; // 1 bit is_load, 2 bit cache slot, 2 bit register_target, 2 bit height, 2 bit width, 1 bit zero_flag, 1 bit skip_flag, 3 bit apu
decoded_loop_instruction loop_instr;
loopmux loopmux (
    .addr         (raw_instruction[4:6]),
    .in           (loop_ro_data),
    .independent  (raw_instruction[2]), // for start loop instructions
    .new_loop     (raw_instruction[3]),
    .loop_instr   (loop_instr)
);
endmodule


