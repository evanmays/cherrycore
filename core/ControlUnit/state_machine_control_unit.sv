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
// 	 calculate instruction queue copy amount and put in queue
//   update pc and break loop if pc > program_instr_count
// notify host computer of completion
module control_unit(
  input               clk,
  input               reset
);
enum {IDLE, PREPARE_PROGRAM, DECODE, START_NEW_LOOP, INCREMENT_LOOP, UPDATE_APU, INIT_PREFETCH, INSERT_TO_QUEUE, UPDATE_PC, FINISH_PROGRAM} S;
reg [15:0]  pc;
reg [15:0]  program_end_pc;
reg [6:0]   program_header_cache_addr;


// Loop variables
parameter LOG_LOOP_CNT;
parameter LOOP_CNT = (1 << LOG_LOOP_CNT);
reg signed [LOG_LOOP_CNT:0] loop_depth; // -1 is empty
reg [LOOP_CNT] [17:0] loop_value;
reg [LOOP_CNT] loop_is_independent;
wire loop_depth_plus_one;
assign loop_depth_plus_one = loop_depth + 1;

always @(posedge clk) begin
  case (S)
    IDLE: begin
      S <= PREPARE_PROGRAM;
    end
    PREPARE_PROGRAM: begin
      pc <= 0;
      program_end_pc <= 10;
      S <= DECODE;
    end
    DECODE: begin
      case (instr_type)
        INSTR_TYPE_LOOP: S <= loop_instr.is_new_loop ? START_NEW_LOOP : INCREMENT_LOOP;
        INSTR_TYPE_RAM: S <= INSERT_TO_QUEUE;// INIT_PREFETCH;
        default: S <= INSERT_TO_QUEUE;
      endcase
    end
    START_NEW_LOOP: begin
      loop_stack_empty <= 0;
      loop_value[loop_depth_plus_one] <= 0;
      loop_depth <= loop_depth_plus_one;
      loop_is_independent[loop_depth_plus_one] <= loop_instr.is_independent;
      S <= UPDATE_APU;
    end
    INCREMENT_LOOP: begin
      loop_value[loop_depth] <= loop_value[loop_depth] + (loop_is_independent[loop_depth_plus_one] ? (loop_remaining_iterations <= SUPERSCALAR_WIDTH ? loop_remaining_iterations : SUPERSCALAR_WIDTH) : 1);
      if (loop_remaining_iterations <= SUPERSCALAR_WIDTH) begin
        // need to pop cur loop off stack. but apu needs cur loops di first.
        // update_pc also needs to know if cur loop depth first so it can jump the right amount
      end
      S <= UPDATE_APU;
    end
    UPDATE_APU: begin
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
      // this also needs to know if loop 
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
    program_header_cache_addr <= 0;
    loop_depth <= -1;
    loop_value <= 0;
    loop_stack_empty <= 1;
  end
end

endmodule

