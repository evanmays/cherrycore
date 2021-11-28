typedef enum {LOOP_TYPE_START_INDEPENDENT, LOOP_TYPE_START_SLOW, LOOP_TYPE_JUMP_OR_END} e_loop_instr_type;

parameter INSTR_TYPE_LOAD_STORE   = 2'd0;
parameter INSTR_TYPE_RAM          = 2'd1;
parameter INSTR_TYPE_ARITHMETIC   = 2'd2;
parameter INSTR_TYPE_LOOP         = 2'd3;

typedef struct packed {
  reg is_new_loop;
  reg [17:0] iteration_count;
  reg [5:0] jump_amount;
  reg is_independent;
} decoded_loop_instruction;