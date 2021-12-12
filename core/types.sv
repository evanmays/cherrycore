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

typedef struct packed {
  dma_instruction raw_instr_data;
} dma_stage_1_instr; // Used in stage 1: Read cache

typedef struct packed {
  logic       [17:0]  dat;
  dma_instruction     raw_instr_data;
} dma_stage_2_instr; // Used in stage 2: Execute DMA

typedef struct packed {
  logic       [17:0]  dat;
  dma_instruction     raw_instr_data;
} dma_stage_3_instr; // Used in stage 3: Write cache

//
// Regfile Pipeline Data
//
typedef struct packed {
  logic         valid;
  logic         is_load;
  logic [1:0]   cache_slot;
  logic [10:0]  cache_addr;
  logic [1:0]   regfile_reg;
  // logic         zero_flag; // TODO
  // logic         skip_flag; // TODO
} regfile_instruction;

//
// Processing Pipeline Data (Depracated)
//
typedef struct packed {
  logic       valid;
  logic [1:0] reg_in;
  logic [1:0] reg_out;
} arithmetic_instruction;

//
// Processing Pipeline Data
//
typedef struct packed {
  logic       valid;
  logic [2:0] category; // check assembler.py
  logic [5:0] options;  // format depends on the category
} math_instr;