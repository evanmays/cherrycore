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
// TODO: Regfile Pipeline Data
//

//
// TODO: Processing Pipeline Data
//