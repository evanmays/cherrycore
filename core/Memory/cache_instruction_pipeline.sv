// Deals with cisa_load and cisa_store
// Moves data between dcache and regfile
module cache_instruction_pipeline(
  input                       clk,
  input   regfile_instruction instr,

  // Stage 1
  output  reg [0:17]          regfile_read_addr,
  output  reg [12:0]          cache_read_addr,

  // Result of stage 1
  input   wire [0:17]         regfile_dat_r,
  input   wire [0:17]         cache_dat_r,

  // Stage 2
  output  reg [0:1]           regfile_write_addr,
  output  reg [0:17]          regfile_dat_w,
  output  reg                 regfile_we,
  output  reg [12:0]          cache_write_addr,
  output  reg [0:17]          cache_dat_w,
  output  reg                 cache_we
);

regfile_instruction instr_1, instr_2;
assign instr_1 = instr;

//
// Stage 1: Read from regfile or memory
//
always_ff @(posedge clk) begin
  instr_2 <= instr;
  if (instr_1.valid) begin
    if (instr_1.is_load) begin
      cache_read_addr <= {instr_1.cache_slot, instr_1.cache_addr};
    end else begin
      regfile_read_addr <= instr_1.regfile_reg; // TODO: add thread here
    end
  end
end

//
// Stage 2: Write to regfile or memory
//
always_ff @(posedge clk) begin
  if (instr_2.valid) begin
    regfile_we  <= instr_2.is_load;
    cache_we    <= !instr_2.is_load;
    if (instr_2.is_load) begin
      regfile_write_addr  <= instr_2.regfile_reg; // TODO: add thread here
      regfile_dat_w       <= cache_dat_r;
    end else begin
      cache_write_addr  <= {instr_2.cache_slot, instr_2.cache_addr};
      cache_dat_w       <= regfile_dat_r;
    end
  end
end
endmodule