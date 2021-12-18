module fake_control_unit #(parameter LOG_SUPERSCALAR_WIDTH=3)(
  input               clk,
  input               reset,

  // Push to instruction queue ports
  output reg  [17:0] cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr,
  output reg         queue_we,
  output reg  [1:0]  queue_instr_type,
  output reg  [0:8] queue_arith_instr,
  output reg  [0:2]  queue_ram_instr,
  output reg  [0:6] queue_ld_st_instr
);
parameter INPUT_CACHE_SLOT = 2'd2;
parameter OUTPUT_CACHE_SLOT = 2'd2;
parameter INPUT_REG = REG_MATMUL_INPUT;
parameter OUTPUT_REG = REG_MATMUL_OUTPUT;
reg [7:0] pos;
always @(posedge clk) begin
  if (reset) begin
    pos <= 0;
    queue_we <= 0;
  end else begin
    pos <= pos < 5 ? pos + 1 : pos;
    queue_we <= pos < 5;
    case (pos)
      0: begin
        queue_instr_type <= INSTR_TYPE_RAM;
        queue_ram_instr <= {1'b0, INPUT_CACHE_SLOT}; // RAM to cache
        cache_addr <= 0;
        d_cache_addr <= 1;
        main_mem_addr <= 16;
        d_main_mem_addr <= 4;
      end
      1: begin
        queue_instr_type <= INSTR_TYPE_LOAD_STORE;
        queue_ld_st_instr <= {1'b1, INPUT_CACHE_SLOT, INPUT_REG, 1'b0, 1'b0};
        cache_addr <= 0;
        d_cache_addr <= 1;
      end
      2: begin
        queue_instr_type <= INSTR_TYPE_ARITHMETIC;
        queue_arith_instr <= 9'b000110000; // this is gt0 but the actual arithmetic thing just runs relu regardless
      end
      3: begin
        queue_instr_type <= INSTR_TYPE_LOAD_STORE;
        queue_ld_st_instr <= {1'b0, OUTPUT_CACHE_SLOT, OUTPUT_REG, 1'b0, 1'b0};
        cache_addr <= 0;
        d_cache_addr <= 1;
      end
      4: begin
        queue_instr_type <= INSTR_TYPE_RAM;
        queue_ram_instr <= {1'b1, OUTPUT_CACHE_SLOT}; // slot 1 to RAM
        cache_addr <= 0;
        d_cache_addr <= 1;
        main_mem_addr <= 112;
        d_main_mem_addr <= 1;
      end
    endcase
  end
end

endmodule
