typedef enum {LOOP_TYPE_START_INDEPENDENT, LOOP_TYPE_START_SLOW, LOOP_TYPE_JUMP_OR_END} e_loop_instr_type;

typedef enum {INSTR_TYPE_LOAD_STORE, INSTR_TYPE_RAM, INSTR_TYPE_ARITHMETIC, INSTR_TYPE_LOOP, INSTR_TYPE_ERROR} e_instr_type;

typedef struct packed {
  reg is_load; // 1 for load, 0 for store
  reg [1:0] target;
  reg [1:0] height, width;
  reg zero_flag; // only used for load
  reg skip_flag;
} memory_unit_control_signals;

typedef struct packed {
  reg [2:0] apu;
  memory_unit_control_signals control;
} decoded_load_store_instruction;

typedef struct packed {
  reg [2:0] apu;
} decoded_ram_instruction;

typedef struct packed {
  reg [12:0] one_hot_enable; // one hot encoded for which alu (matmul, mulacc, binop, etc) to activate
  reg [1:0] target; // not all processing instructions use this. See ISA
  reg [1:0] source;
  reg is_default; // 1 for relu, 0 for gt0. 1 for add. 0 for sub. 1 for max accumulate. 0 for max nonaccumulate. 1 for sum accumulate. 0 for sum nonaccumulate
} decoded_arithmetic_instruction;

typedef struct packed {
  reg is_new_loop;
  reg [17:0] iteration_count;
  reg [5:0] jump_amount;
  reg is_independent;
} decoded_loop_instruction;