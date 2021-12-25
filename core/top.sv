module top #(parameter CLK_HZ=50000000) (
input               clk     , // Top level system clock input.
input               sw_0 , // reset switch
input   wire        uart_rxd, // UART Recieve pin.
output  wire        uart_txd,  // UART transmit pin.
output  wire [7:0]  led,
output  wire        program_complete
);
wire                freeze;
assign freeze = dma_busy;
assign led[1] = freeze;
//assign led[5] = queue_empty;
assign program_complete = prog_end_instr_valid & !freeze;
assign led[2] = dma_stage_3_dcache_write.raw_instr_data.valid;
wire                  queue_empty;

dma_stage_1_instr   dma_stage_1_dcache_read;
dma_stage_2_instr   dma_stage_2_execute;
dma_stage_3_instr   dma_stage_3_dcache_write;

wire          dma_busy;
regfile_instruction cache_instr_stage_1, cache_load_instr_stage_2, cache_store_instr_stage_2;
math_instr          m_instr;
wire prog_end_instr_valid;
always @(posedge clk) begin
  if (sw_0) begin
    cache_store_instr_stage_2 <= 0;
  end else if (!freeze) begin
    cache_store_instr_stage_2 <= cache_instr_stage_1;
  end
end
wire q_re;
assign q_re = !queue_empty & !freeze; // do we lose data?

wire [17:0] cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr;
wire queue_we;
wire [1:0]  queue_instr_type;
wire [4:0] queue_copy_count;
wire [8:0] queue_arith_instr;
wire  [2:0]  queue_ram_instr;
wire  [6:0] queue_ld_st_instr;
wire instr_queue_stall_push;
instruction_queue instruction_queue (
  .reset(sw_0),
  .clk(clk),

  // Pop
  .re(q_re),
  .out_dma_instr(dma_stage_1_dcache_read),
  .out_math_instr(m_instr),
  .out_cache_instr(cache_instr_stage_1),
  .out_prog_end_valid(prog_end_instr_valid),
  .empty(queue_empty),

  // Push
  .we(queue_we),
  .in_instr_type(queue_instr_type),
  .copy_count(queue_copy_count),
  .cache_addr(cache_addr),
  .d_cache_addr(d_cache_addr),
  .main_mem_addr(main_mem_addr),
  .d_main_mem_addr(d_main_mem_addr),
  .in_arith_instr(queue_arith_instr),
  .in_ram_instr(queue_ram_instr),
  .in_ld_st_instr(queue_ld_st_instr),
  .stall_push(instr_queue_stall_push)
);
wire [0:15] raw_instruction;
wire [15:0] pc;
wire        ro_data_addr;
wire [0:4*9*18-1] prog_apu_formula;
wire [24*8-1:0]   prog_loop_ro_data;
control_unit #(4) control (
  .clk(clk),
  .reset(sw_0),


  .raw_instruction(raw_instruction),
  .pc(pc),

  .prog_apu_formula(prog_apu_formula),
  .prog_loop_ro_data(prog_loop_ro_data),
  .ro_data_addr(ro_data_addr),

  .instr_queue_stall_push(instr_queue_stall_push),
  .cache_addr(cache_addr),
  .main_mem_addr(main_mem_addr),
  .d_cache_addr(d_cache_addr),
  .d_main_mem_addr(d_main_mem_addr),
  .queue_we(queue_we),
  .queue_instr_type(queue_instr_type),
  .queue_copy_count(queue_copy_count),
  .queue_arith_instr(queue_arith_instr),
  .queue_ram_instr(queue_ram_instr),
  .queue_ld_st_instr(queue_ld_st_instr)
);

fake_icache icache (
  .raw_instruction(raw_instruction),
  .pc(pc)
);

fake_ro_data ro_data (
  .addr(ro_data_addr),
  .prog_apu_formula(prog_apu_formula),
  .prog_loop_ro_data(prog_loop_ro_data)
);

dma_uart dma (
.clk(clk),
.reset(sw_0),
.instr(dma_stage_2_execute),
.busy(dma_busy),
// .freeze(freeze), jk, no one can freeze the DMA

// command cache signals
.cache_write_port(dma_stage_3_dcache_write),

// board pins
.uart_rxd(uart_rxd), // UART Recieve pin.
.uart_txd(uart_txd)  // UART transmit pin.

);

wire [17:0] cache_load_dat_stage_2, cache_store_dat_stage_2;
dcache dcache (
.clk(clk),
.freeze(freeze),
.cisa_load_instr_stage_1  (cache_instr_stage_1),
.cisa_load_instr_stage_2  (cache_load_instr_stage_2),
.cisa_load_dat_stage_2    (cache_load_dat_stage_2),
.cisa_store_instr_stage_2 (cache_store_instr_stage_2),
.cisa_store_dat_stage_2   (cache_store_dat_stage_2),
.dma_read_port_in         (dma_stage_1_dcache_read),
.dma_read_port_out        (dma_stage_2_execute),
.dma_write_port           (dma_stage_3_dcache_write),
.reset(sw_0)
);

wire [0:5] processing_read_addr_regfile, processing_write_addr_regfile;
wire [17:0] processing_regfile_dat_r, processing_regfile_dat_w;
wire processing_regfile_we;
regfile #(.LOG_SUPERSCALAR_WIDTH(4), .REG_WIDTH(18)) regfile(
.clk(clk),
.reset(sw_0),
.freeze(freeze),
.port_a_read_addr(processing_read_addr_regfile),
.port_a_out(processing_regfile_dat_r),
.port_c_we(processing_regfile_we), // .port_c_we(1'd1),
.port_c_write_addr(processing_write_addr_regfile),//.port_c_write_addr(4'd0),
.port_c_in(processing_regfile_dat_w), // .port_c_in(18'd150),
.port_b_read_addr({cache_instr_stage_1.superscalar_thread, cache_instr_stage_1.regfile_reg}),
.port_b_out(cache_store_dat_stage_2),
.port_d_we(cache_load_instr_stage_2.valid && cache_load_instr_stage_2.is_load), // fun fact: if you make a typo and instead type cache_load_instr_stage_2.is_load.valid the compiler wont say anything!!!
.port_d_write_addr({cache_load_instr_stage_2.superscalar_thread, cache_load_instr_stage_2.regfile_reg}),
.port_d_in(cache_load_dat_stage_2)
);

math_pipeline processing_pipeline(
.clk(clk),
.reset(sw_0),
.freeze(freeze),
.instr(m_instr),
.regfile_read_addr(processing_read_addr_regfile),
.stage_2_dat(processing_regfile_dat_r),
.regfile_write_addr(processing_write_addr_regfile),
.regfile_dat_w(processing_regfile_dat_w),
.regfile_we(processing_regfile_we)
);
endmodule