module math_pipeline(
  input                           clk,
  input                           freeze,
  input                           reset,
  input   math_instr              instr,

  // Stage 1
  output  reg [5:0]             regfile_read_addr,

  // Result of stage 1
  input       [SZ*SZ*18-1:0]    stage_2_dat,

  // Stage 3
  output  reg [5:0]             regfile_write_addr,
  output  reg [SZ*SZ*18-1:0]    regfile_dat_w,
  output  reg                   regfile_we
);
parameter SZ=4;
math_instr instr_1, instr_2, instr_3;
logic [SZ*SZ*18-1:0] stage_3_dat_reg, stage_3_dat_wire;

always @(posedge clk) begin
  if (!freeze) begin
    //
    // Stage 1: Initiate Read register. (Delete this, it can be done combinatorially) Maybe can just turn these into assign statements for fast testing and to keep all the logic in the right place
    //
    instr_1 <= instr;
    if (instr.valid) regfile_read_addr <= {instr.superscalar_thread, REG_MATMUL_INPUT};

    //
    // Stage 2: Allow Regfile to do the Read
    //
    instr_2 <= instr_1;



    //
    // Stage 3: Execute
    //
    instr_3 <= instr_2;
    if (instr_2.valid) begin
      stage_3_dat_reg <= stage_3_dat_wire;
    end

    //
    // Stage 4: Writeback
    //
    regfile_we <= instr_3.valid;
    regfile_dat_w <= stage_3_dat_reg;
    regfile_write_addr <= {instr_3.superscalar_thread, REG_MATMUL_OUTPUT};
  end
  if (reset) begin
    regfile_read_addr <= 0;
    regfile_write_addr <= 0;
    regfile_dat_w <= 0;
    regfile_we <= 1'b0;

    instr_1 <= 0;
    instr_2 <= 0;
    instr_3 <= 0;
    stage_3_dat_reg <= 0;
  end
end

UnopALU #(.LEN(SZ*SZ)) UnopALU(
  .vector_in(stage_2_dat),
  .vector_out(stage_3_dat_wire)
);
endmodule