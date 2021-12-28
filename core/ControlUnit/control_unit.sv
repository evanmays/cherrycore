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
//   notify host computer of completion (happens when instruction queue pops the end of program marker from the queue)
module control_unit #(parameter LOG_SUPERSCALAR_WIDTH=3)(
  input               clk,
  input               reset,

  // Program execution queue ports
  input               start_prog, // todo: support
  output reg [6:0]    program_header_cache_addr,

  // Instruction Fetch ports (fetch and decode happen in same cycle. so can't register the icache output)
  input       [0:15]  raw_instruction, // using bit so we can cast raw_instruction[0:1] to instruction_type
  output reg  [15:0]  pc,

  // Program (header) ro_data Ports
  input  wire [0:4*9*18-1] prog_apu_formula, // each formula has 8 coefficients and 1 constant. all 18 bit values. We can load 4 formulas at a time.
  input  wire [24*8-1:0]   prog_loop_ro_data, // 8 iteration counts and jump amounts. Can load in 1 cycle.
  output reg               ro_data_addr,

  // Push to instruction queue ports
  input  wire        instr_queue_stall_push,
  output reg  [17:0] cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr,
  output reg         queue_we,
  output reg  [1:0]  queue_instr_type,
  output reg  [LOG_SUPERSCALAR_WIDTH:0] queue_copy_count,
  output reg  [8:0]  queue_arith_instr,
  output reg  [2:0]  queue_ram_instr, // {is_write, cache_slot}
  output reg  [6:0]  queue_ld_st_instr, // {is_load, cache_slot, regfile_reg, zero_flag, skip_flag}

  output logic program_error
);
enum {IDLE, PREPARE_PROGRAM_0, PREPARE_PROGRAM_1, DECODE, START_NEW_LOOP, INCREMENT_LOOP, UPDATE_APU, INSERT_TO_QUEUE, UPDATE_PC, FINISH_PROGRAM_1, FINISH_PROGRAM_2} S;

// Info about current program
reg [15:0]  program_end_pc;
reg [24*8-1:0] loop_ro_data;

localparam SUPERSCALAR_WIDTH = (1 << LOG_SUPERSCALAR_WIDTH);

// Loop variables
localparam LOG_LOOP_CNT = 3; // right now we have a strong amount of loops allowed in the stack == amount of loops allowed in ro data. We can break this relationship in the future.
localparam LOOP_CNT = (1 << LOG_LOOP_CNT);
reg signed [LOG_LOOP_CNT:0] loop_cur_depth; // -1 is empty
`define LOOP_CUR_DEPTH loop_cur_depth[LOG_LOOP_CNT-1:0]
reg [17:0] loop_stack_value [0:LOOP_CNT-1];
reg [17:0] loop_stack_total_iterations [0:LOOP_CNT-1];
reg [5:0] loop_stack_jump_amount [0:LOOP_CNT-1];
reg loop_stack_is_independent [0:LOOP_CNT-1];
reg [LOG_LOOP_CNT-1:0] loop_stack_name [LOOP_CNT-1:0]; // name for loop at each stack depth positon. i.e. i, j, k, l, m, ...  ascii(val+'j') tells you the name which corresponds to the cherry program
// verilator lint_off WIDTH
wire [LOG_LOOP_CNT-1:0] loop_cur_depth_plus_one = loop_cur_depth + 1'b1;
// verilator lint_on WIDTH
wire max_loops = loop_cur_depth + 1 < 0;
reg [5:0] jump_amount;
wire [17:0] loop_cur_remaining_iterations = loop_stack_total_iterations[`LOOP_CUR_DEPTH] - loop_stack_value[`LOOP_CUR_DEPTH];

// APU
localparam LOG_APU_CNT = 3;
localparam APU_CNT = (1 << LOG_APU_CNT);
reg [LOG_LOOP_CNT-1:0] apu_in_loop_var; // input set by loop update FSM step
reg [17:0] apu_in_di; // input set by loop update FSM step
reg [18*8-1:0] apu_linear_formulas [0:APU_CNT-1]; // 8 coefficients
reg [17:0] apu_address_registers [0:APU_CNT-1]; // current data. starts at the constant vals

always @(posedge clk) begin
  case (S)
    IDLE: begin
      S <= PREPARE_PROGRAM_0;
      ro_data_addr <= 0;
    end
    PREPARE_PROGRAM_0: begin
      pc <= 6;
      program_end_pc <= 13; // should be one spot after the last spot in the program. End of program (non inclusive)
      ro_data_addr <= 1;
      S <= PREPARE_PROGRAM_1;
      for (integer i = 0; i < 4; i = i + 1) begin
        apu_address_registers[i]  <= prog_apu_formula[i*9*18+8*18 +: 18];
        apu_linear_formulas[i]    <= prog_apu_formula[i*9*18 +: 8*18];
      end
      loop_ro_data <= prog_loop_ro_data;
    end
    PREPARE_PROGRAM_1: begin
      S <= DECODE;
      for (integer i = 0; i < 4; i = i + 1) begin
        apu_address_registers[i + 4]  <= prog_apu_formula[i*9*18+8*18 +: 18];
        apu_linear_formulas[i + 4]    <= prog_apu_formula[i*9*18 +: 8*18];
      end
    end
    DECODE: begin
      case (instruction_type)
        INSTR_TYPE_LOOP: S <= loop_instr.is_new_loop ? START_NEW_LOOP : INCREMENT_LOOP;
        default: S <= INSERT_TO_QUEUE;
      endcase
    end
    START_NEW_LOOP: begin
      if (max_loops) program_error <= 1;
      loop_stack_value[loop_cur_depth_plus_one] <= 0;
      // verilator lint_off WIDTH
      loop_cur_depth <= loop_cur_depth_plus_one;
      // verilator lint_on WIDTH
      loop_stack_is_independent[loop_cur_depth_plus_one] <= loop_instr.is_independent;
      loop_stack_jump_amount[loop_cur_depth_plus_one] <= loop_instr.jump_amount;
      loop_stack_total_iterations[loop_cur_depth_plus_one] <= loop_instr.iteration_count;
      loop_stack_name[loop_cur_depth_plus_one] <= loop_instr.name;
      S <= UPDATE_APU;
    end
    INCREMENT_LOOP: begin
      `ifdef FORMAL
      assert(loop_cur_depth >= 0);
      `endif
      loop_stack_value[`LOOP_CUR_DEPTH]  <= loop_stack_value[`LOOP_CUR_DEPTH] + (loop_stack_is_independent[`LOOP_CUR_DEPTH] ? (loop_cur_remaining_iterations <= SUPERSCALAR_WIDTH ? loop_cur_remaining_iterations : SUPERSCALAR_WIDTH) : 1); // might be redundent case for independent and < superscalar width
      apu_in_loop_var <= loop_stack_name[`LOOP_CUR_DEPTH];
      
      if (loop_stack_is_independent[`LOOP_CUR_DEPTH] && loop_cur_remaining_iterations <= SUPERSCALAR_WIDTH) begin
        apu_in_di <= -1 * loop_stack_total_iterations[`LOOP_CUR_DEPTH];
        loop_cur_depth <= loop_cur_depth - 1;
      end else if (loop_cur_remaining_iterations == 1) begin
        apu_in_di <= -1 * loop_stack_total_iterations[`LOOP_CUR_DEPTH];
        loop_cur_depth <= loop_cur_depth - 1;
      end else begin
        apu_in_di <= (loop_stack_is_independent[`LOOP_CUR_DEPTH] ? SUPERSCALAR_WIDTH : 1);
        jump_amount <= loop_stack_jump_amount[`LOOP_CUR_DEPTH];
      end
      S <= UPDATE_APU;
    end
    UPDATE_APU: begin
      for (integer k = 0; k < APU_CNT ; k = k + 1) begin // will this synthesize properly? do we need to use macros?
        apu_address_registers[k] <= apu_address_registers[k] + apu_in_di * daddr_di(apu_linear_formulas[k], apu_in_loop_var);
      end
      S <= UPDATE_PC;
    end
    INSERT_TO_QUEUE: if (!instr_queue_stall_push) begin
      assert(loop_cur_depth >= 0);
      if (instruction_type == INSTR_TYPE_LOAD_STORE) begin
        cache_addr     <= apu_address_registers[ld_st_instr[1:3]];
        d_cache_addr    <= daddr_di(apu_linear_formulas[ld_st_instr[1:3]], `LOOP_CUR_DEPTH);
      end
      if (instruction_type == INSTR_TYPE_RAM) begin
        cache_addr     <= apu_address_registers[ram_instr[1:3]];
        main_mem_addr  <= apu_address_registers[ram_instr[4:6]];
        d_cache_addr    <= daddr_di(apu_linear_formulas[ram_instr[1:3]], `LOOP_CUR_DEPTH);
        d_main_mem_addr <= daddr_di(apu_linear_formulas[ram_instr[4:6]], `LOOP_CUR_DEPTH);
      end
      S <= UPDATE_PC;
      queue_we <= 1;
      queue_instr_type  <= instruction_type;
      queue_copy_count  <= loop_stack_is_independent[`LOOP_CUR_DEPTH]
                            ? (loop_cur_remaining_iterations <= SUPERSCALAR_WIDTH
                                ? loop_cur_remaining_iterations
                                : SUPERSCALAR_WIDTH)
                            : 1'd1;
      queue_arith_instr <= arith_instr;
      queue_ram_instr   <= {ram_instr[0], ram_instr[7:8]};
      queue_ld_st_instr <= {ld_st_instr[0], ld_st_instr[4:9]};
    end
    UPDATE_PC: begin
      queue_we <= 0;
      pc <= pc + 1 - jump_amount;
      jump_amount <= 0;
      S <= (pc + 1 - jump_amount) >= program_end_pc ? FINISH_PROGRAM_1
                                                    : DECODE;
    end
    FINISH_PROGRAM_1: if (!instr_queue_stall_push) begin
      queue_we <= 1;
      queue_instr_type  <= INSTR_TYPE_PROG_END;
      S <= FINISH_PROGRAM_2;
    end
    FINISH_PROGRAM_2: begin
      queue_we <= 0;
      // S <= IDLE;
    end
  endcase
  if (reset) begin
    program_error <= 0;
    S <= IDLE;
    pc <= 0;
    program_end_pc <= 0;
    ro_data_addr <= 0;
    loop_ro_data <= 0;
    program_header_cache_addr <= 0;
    loop_cur_depth <= -1;
    for (integer i=0; i<LOOP_CNT; i=i+1) begin
      loop_stack_value[i] <= 18'd0;
      loop_stack_total_iterations[i] <= 18'd0;
      loop_stack_jump_amount[i] <= 6'd0;
      loop_stack_name[i] <= {LOG_LOOP_CNT{1'b0}};
    end
    jump_amount <= 0;
    apu_in_loop_var <= 0;
    apu_in_di <= 0;
    for (integer i=0; i<APU_CNT; i=i+1) begin
      apu_address_registers[i] <= 18'd0;
      apu_linear_formulas[i] <= 144'd0;
    end

    queue_we <= 0;
    queue_instr_type <= 0;
    queue_copy_count <= 0;
  end
end

function [17:0] daddr_di ( input [0:18*8-1] linear_formula, input [LOG_LOOP_CNT-1:0] loop_var );
  begin
    // daddr_di = linear_formula[loop_var*18 +: 18]; // synthesizes poorly
    case (loop_var)
      3'd0: daddr_di = linear_formula[0*18 +: 18];
      3'd1: daddr_di = linear_formula[1*18 +: 18];
      3'd2: daddr_di = linear_formula[2*18 +: 18];
      3'd3: daddr_di = linear_formula[3*18 +: 18];
      3'd4: daddr_di = linear_formula[4*18 +: 18];
      3'd5: daddr_di = linear_formula[5*18 +: 18];
      3'd6: daddr_di = linear_formula[6*18 +: 18];
      3'd7: daddr_di = linear_formula[7*18 +: 18];
    endcase
	end
endfunction

//
// Partial Decoder
//
wire [1:0] instruction_type = raw_instruction[0:1] == 2'd0 ? INSTR_TYPE_LOAD_STORE : raw_instruction[0:1] == 2'd1 ? INSTR_TYPE_RAM : raw_instruction[0:1] == 2'd2 ? INSTR_TYPE_ARITHMETIC : INSTR_TYPE_LOOP;
wire [8:0] arith_instr = raw_instruction[2:10];
wire [0:8]  ram_instr   = raw_instruction[2:10]; // 1 bit is_write, 6 bit 2 apus, 2 bits cache slot
wire [0:9] ld_st_instr = raw_instruction[2:11]; // 1 bit is_load, 3 bit apu, 2 bit cache slot, 2 bit register_target, 1 bit zero_flag, 1 bit skip_flag, fill (TODO add 2 bit height, 2 bit width)
decoded_loop_instruction loop_instr;
loopmux loopmux (
    .addr         (raw_instruction[4:6]),
    .in           (loop_ro_data),
    .independent  (raw_instruction[2]), // for start loop instructions
    .new_loop     (raw_instruction[3]),
    .loop_instr   (loop_instr)
);

`ifdef FORMAL
  initial restrict(reset);
  always @($global_clock) begin
    restrict(clk == !$past(clk));
    if (!$rose(clk)) begin
      assume($stable(reset));
      assume($stable(raw_instruction));
      assume($stable(prog_apu_formula));
      assume($stable(prog_loop_ro_data));
    end
  end
  initial begin
    f_past_valid = 1'b0;
  end
  always @(posedge clk) begin
    // we dont actually use our ports every cycle. So lets cache the ports to so we can get a real $past that just looks at what the port was the last time it mattered.
  f_past_valid <= 1'b1;
  if (f_past_valid) begin
    
    assert(loop_cur_depth_plus_one == loop_cur_depth + 1);


    // Instruction Queue Push

    // Instruction Fetch
    // if ($past(instruction_type) != INSTR_TYPE_LOOP && !$past(reset)) assert(pc >= $past(pc));
    if ($stable(pc)) assume($stable(raw_instruction));

    // Program Fetch and Execution queue
    if (!$rose(program_complete)) begin
      assume($stable(prog_apu_formula));
      assume($stable(prog_loop_ro_data));
    end
  end
  
  end
`endif
endmodule


