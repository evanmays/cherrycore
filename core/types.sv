//
//  DMA Pipeline Data
//

typedef struct packed {
  logic           valid; // if queue had no instruction
  logic           mem_we;
  logic   [6:0]   main_mem_addr;
  logic   [1:0]   cache_slot;
  logic   [10:0]  cache_addr;
} dma_instruction; // Ouput of stage 0: Pulled from queue. Edit valid to be if queue missingg instruction OR pipeline frozen

// todo, should isntead do stage 1 read dma, stage 2 write/read cache, stage 3 write dma
typedef struct packed {
  dma_instruction raw_instr_data;
} dma_stage_1_instr; // Used in stage 1: Read from L3 if needed

typedef struct packed {
  logic       [287:0]  dat;
  dma_instruction     raw_instr_data;
} dma_stage_2_instr; // Used in stage 2: Read or write cache

typedef struct packed {
  logic       [287:0]  dat;
  dma_instruction     raw_instr_data;
} dma_stage_3_instr; // Used in stage 3: Write to vram

//
// Regfile Pipeline Data
//
typedef struct packed {
  logic         valid;
  logic         is_load;
  logic [1:0]   cache_slot;
  logic [10:0]  cache_addr;
  logic [3:0]   superscalar_thread; // used for deciding which regfile reg
  logic [1:0]   regfile_reg;
  // logic         zero_flag; // TODO
  // logic         skip_flag; // TODO
} regfile_instruction;

//
// Processing Pipeline Data
//
typedef struct packed {
  logic       valid;
  logic [2:0] category; // check assembler.py
  logic [5:0] options;  // format depends on the category
  logic [3:0] superscalar_thread; // used for deciding which regfile reg
} math_instr;

parameter REG_MATMUL_INPUT = 2'd0;
parameter REG_MATMUL_WEIGHTS = 2'd1;
parameter REG_MATMUL_OUTPUT = 2'd2;
parameter REG_MATMUL_ACC = 2'd3;


//
// Other
//
typedef enum {LOOP_TYPE_START_INDEPENDENT, LOOP_TYPE_START_SLOW, LOOP_TYPE_JUMP_OR_END} e_loop_instr_type;

parameter INSTR_TYPE_LOAD_STORE   = 2'd0;
parameter INSTR_TYPE_RAM          = 2'd1;
parameter INSTR_TYPE_ARITHMETIC   = 2'd2;
parameter INSTR_TYPE_LOOP         = 2'd3;
parameter INSTR_TYPE_PROG_END         = 2'd3; // instr type 3 is loop in control unit and in instruction queue it's program end marker

typedef struct packed {
  reg is_new_loop;
  reg [17:0] iteration_count;
  reg [5:0] jump_amount;
  reg is_independent;
  reg [2:0] name; // ascii_cast('i'+name) to get the character
} decoded_loop_instruction;

typedef struct packed {
  logic [4:0] copy_count;
  logic [17:0]             addr;
  logic [17:0]             d_addr;
} initiate_prefetch_command;