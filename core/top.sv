`default_nettype	none
module top #(parameter CLK_HZ=50000000) (
input               clk     , // Top level system clock input.
input               sw_0 , // reset switch
input   wire        uart_rxd, // UART Recieve pin.
output  wire        uart_txd,  // UART transmit pin.
output  wire [7:0]  led,
output wire error
);
parameter SZ = 4;
wire                freeze;
assign freeze = dma_busy;
assign led[1] = freeze;
//assign led[5] = queue_empty;
assign led[2] = dma_stage_3_main_mem_write.raw_instr_data.valid;
assign led[4] = error;
assign error = mem_read_completion_fifo_err | packet_send_mem_write_err | packet_send_prog_complete_err;
wire                  queue_empty;

dma_stage_1_instr   dma_stage_1_L3_read;
dma_stage_2_instr   dma_stage_2_L1_read_or_write;
dma_stage_3_instr   dma_stage_3_main_mem_write;

logic          dma_busy;
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
  .out_dma_instr(dma_stage_1_L3_read),
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

  .instr_queue_stall_push(instr_queue_stall_push | prefetch_initiate_queue_full),
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
logic prefetch_command_we;
initiate_prefetch_command prefetch_command_dat_w;
always @(posedge clk)
  // if control unit outputs cisa_mem_read, then prefetch
  if (  queue_we &&
        queue_instr_type == INSTR_TYPE_RAM &&
        !queue_ram_instr[2] // not a mem_write. it's a mem_read
      ) begin
    prefetch_command_dat_w <= {queue_copy_count, main_mem_addr, d_main_mem_addr};
    prefetch_command_we <= 1;
    $display("prefetch vram addr %d", main_mem_addr);
  end else begin
    prefetch_command_we <= 0;
  end
wire prefetch_initiate_queue_full;
prefetch_initiate_superscalar_fifo packet_send_fifo_mem_read_request(
.clk(clk),
.reset(sw_0),
.re(dma_send_read_queue_re),
.we(prefetch_command_we),
.dat_w(prefetch_command_dat_w),
.dat_r(dma_send_read_queue_data),
.full(prefetch_initiate_queue_full),
.emptyn(dma_send_read_queue_available)
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

//
// IO
//
wire uart_rx_valid;
wire [7:0] uart_rx_data;
wire L3_cache_we;
wire [18*16-1:0] L3_cache_dat_w;
PacketReceiver PacketReceiver (
.clk(clk),
.reset(sw_0),
.rx_interrupt(uart_rx_valid),
.rx_data(uart_rx_data),

.mem_read_result_stb(L3_cache_we),
.mem_read_result_matrix_tile(L3_cache_dat_w)
);
uart_rx #(
.BIT_RATE(19200),
.PAYLOAD_BITS(8),
.CLK_HZ  (CLK_HZ  )
) i_uart_rx(
.clk          (clk          ),
.resetn       (!sw_0       ),
.uart_rxd     (uart_rxd     ),
.uart_rx_en   (1'b1         ),
.uart_rx_valid(uart_rx_valid ),
.uart_rx_data (uart_rx_data)
);

wire L3_not_empty;
wire L3_cache_read_enable = dma_stage_1_L3_read.raw_instr_data.valid && !dma_stage_1_L3_read.raw_instr_data.mem_we;
wire packet_send_fifo_mem_write_command_we = dma_stage_3_main_mem_write.raw_instr_data.valid && dma_stage_3_main_mem_write.raw_instr_data.mem_we;
always @(*) begin
  dma_busy =    (!L3_not_empty && L3_cache_read_enable)
              || (send_write_packet_queue_full && packet_send_fifo_mem_write_command_we)
              || (send_prog_complete_packet_queue_full && prog_end_instr_valid);
end
wire mem_read_completion_fifo_err;

// After a prefetch is complete, it stores the data in this L3 cache. The Dma execution pipeline will read from this L3 cache for cisa_mem_read instructions
reg [18*16-1:0] k;
smplfifo #(.BW(18*16)) L3Cache(
.i_clk(clk),
.i_reset(sw_0),
.i_wr(L3_cache_we),
.i_data(L3_cache_dat_w),
.o_empty_n(L3_not_empty),
.i_rd(!freeze && L3_not_empty && L3_cache_read_enable), // read from L3 cache for cisa_mem_read
.o_data(k),
.o_err(mem_read_completion_fifo_err)
);
dma_instruction raw_data_wire_reg;
always @(posedge clk) begin
  if (sw_0) begin
    dma_stage_2_L1_read_or_write <= 0;
  end else if (!freeze) begin
    // we are adding a cycle delay here. can we remove it?
    dma_stage_2_L1_read_or_write.raw_instr_data  <= dma_stage_1_L3_read.raw_instr_data;
    dma_stage_2_L1_read_or_write.dat <= k;
  end
  
end
wire uart_tx_busy, uart_tx_en;
wire [7:0] uart_tx_data;
wire dma_send_read_queue_re;
wire [15:0] dma_send_read_queue_data;
wire dma_send_read_queue_available;

wire dma_send_write_queue_re;
wire [15:0]    dma_send_write_queue_data;
wire [18*16-1:0] dma_send_write_queue_data2;
wire dma_send_write_queue_available;

wire dma_send_prog_complete_queue_re;
wire dma_send_prog_complete_queue_available;
PacketSender PacketSender(
.clk(clk),
.reset(sw_0),
.tx_busy(uart_tx_busy),
.tx_data(uart_tx_data),
.tx_en(uart_tx_en),

.dma_send_read_queue_data(dma_send_read_queue_data),
.dma_send_read_queue_available(dma_send_read_queue_available),
.dma_send_read_queue_re(dma_send_read_queue_re),

.dma_send_write_queue_data(dma_send_write_queue_data),
.dma_send_write_queue_data2(dma_send_write_queue_data2),
.dma_send_write_queue_available(dma_send_write_queue_available),
.dma_send_write_queue_re(dma_send_write_queue_re),

.dma_send_end_program_queue_available(dma_send_prog_complete_queue_available),
.dma_send_end_program_queue_re(dma_send_prog_complete_queue_re)
);

uart_tx #(
.BIT_RATE(19200),
.PAYLOAD_BITS(8),
.CLK_HZ  (CLK_HZ  )
) i_uart_tx(
.clk          (clk          ),
.resetn       (!sw_0       ),
.uart_txd     (uart_txd     ),
.uart_tx_en   (uart_tx_en   ),
.uart_tx_busy (uart_tx_busy ),
.uart_tx_data (uart_tx_data ) 
);

wire packet_send_mem_write_err;
wire send_write_packet_queue_full;
smplfifo #(.BW(304)) packet_send_fifo_mem_write_command(
.i_clk(clk),
.i_reset(sw_0),
.i_wr(!freeze && !send_write_packet_queue_full && packet_send_fifo_mem_write_command_we),
.i_data({9'd0, dma_stage_3_main_mem_write.raw_instr_data.main_mem_addr, dma_stage_3_main_mem_write.dat}),
.o_empty_n(dma_send_write_queue_available),
.i_rd(dma_send_write_queue_re),
.o_data({dma_send_write_queue_data, dma_send_write_queue_data2}),
.o_err(packet_send_mem_write_err),
.will_overflow(send_write_packet_queue_full)
);
wire packet_send_prog_complete_err;
wire send_prog_complete_packet_queue_full;
smplfifo #(.BW(1)) packet_send_prog_complete_message(
.i_clk(clk),
.i_reset(sw_0),
.i_wr(!freeze && !send_write_packet_queue_full && prog_end_instr_valid),
.i_data(1'b1),
.o_empty_n(dma_send_prog_complete_queue_available),
.i_rd(dma_send_prog_complete_queue_re),
//.o_data(),
.o_err(packet_send_prog_complete_err),
.will_overflow(send_prog_complete_packet_queue_full)
);

//
// Memory (cache and regfile)
//

wire [SZ*SZ*18-1:0] cache_load_dat_stage_2, cache_store_dat_stage_2;
dcache #(.TILE_WIDTH(SZ*SZ*18)) dcache (
.clk(clk),
.freeze(freeze),
.cisa_load_instr_stage_1  (cache_instr_stage_1),
.cisa_load_instr_stage_2  (cache_load_instr_stage_2),
.cisa_load_dat_stage_2    (cache_load_dat_stage_2),
.cisa_store_instr_stage_2 (cache_store_instr_stage_2),
.cisa_store_dat_stage_2   (cache_store_dat_stage_2),
.dma_port_in              (dma_stage_2_L1_read_or_write),
.dma_write_port           (dma_stage_3_main_mem_write),
.reset(sw_0)
);

wire [5:0] processing_read_addr_regfile, processing_write_addr_regfile;
wire [SZ*SZ*18-1:0] processing_regfile_dat_r, processing_regfile_dat_w;
wire processing_regfile_we;
regfile #(.LOG_SUPERSCALAR_WIDTH(4), .REG_WIDTH(SZ*SZ*18)) regfile(
.clk(clk),
.reset(sw_0),
.freeze(freeze),
.port_a_read_addr(processing_read_addr_regfile),
.port_a_out(processing_regfile_dat_r),
.port_c_we(processing_regfile_we), // .port_c_we(1'd1),
.port_c_write_addr(processing_write_addr_regfile),//.port_c_write_addr(4'd0),
.port_c_in(processing_regfile_dat_w),
.port_b_read_addr({cache_instr_stage_1.superscalar_thread, cache_instr_stage_1.regfile_reg}),
.port_b_out(cache_store_dat_stage_2),
.port_d_we(cache_load_instr_stage_2.valid && cache_load_instr_stage_2.is_load), // fun fact: if you make a typo and instead type cache_load_instr_stage_2.is_load.valid the compiler wont say anything!!!
.port_d_write_addr({cache_load_instr_stage_2.superscalar_thread, cache_load_instr_stage_2.regfile_reg}),
.port_d_in(cache_load_dat_stage_2)
);

//
// Math Processor
//

math_pipeline #(.SZ(SZ)) processing_pipeline(
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