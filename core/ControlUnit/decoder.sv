// fully combinatorial decoder
module decoder (
    input wire [0:24*8-1] loop_ro_data,
    input wire [0:15] raw_instruction,
    output decoded_load_store_instruction ld_st_instr,
    output decoded_ram_instruction ram_instr,
    output decoded_arithmetic_instruction arith_instr,
    output decoded_loop_instruction loop_instr,
    output e_instr_type instruction_type
);
  reg loop_mux_independent;
  reg loop_is_new_loop;
  always @(*) begin
    if (raw_instruction[0:4] == 15 || raw_instruction[0:4] == 16) begin
      instruction_type <= INSTR_TYPE_LOAD_STORE;
    end else if (raw_instruction[0:4] == 17 || raw_instruction[0:4] == 18 || raw_instruction[0:4] == 19) begin
      instruction_type <= INSTR_TYPE_LOOP;
    end else if (raw_instruction[0:4] >= 20) begin
      instruction_type <= INSTR_TYPE_ERROR;
    end else begin
      instruction_type <= INSTR_TYPE_ARITHMETIC;
    end
    arith_instr <= 18'd0;
    ld_st_instr <= 12'd0;
    loop_mux_independent <= 1'b0;
    loop_is_new_loop     <= 1'b0;
    case (raw_instruction[0:4])
      0 /* MATMUL */      : arith_instr <= {13'b1000000000000, 5'b0};
      1 /* MULACC */      : arith_instr <= {13'b0100000000000, 5'b0};
      2 /* ADD */         : arith_instr <= {13'b0010000000000, 4'b0, 1'b1};
      3 /* SUB */         : arith_instr <= {13'b0010000000000, 4'b0, 1'b0};
      4 /* MUL */         : arith_instr <= {13'b0001000000000, 5'b0};
      5 /* DIV */         : arith_instr <= {13'b0000100000000, 5'b0};
      6 /* POW */         : arith_instr <= {13'b0000010000000, 5'b0};
      7 /* MAX */         : arith_instr <= {13'b0000001000000, 4'b0, raw_instruction[5]};
      8 /* SUM */         : arith_instr <= {13'b0000000100000, 4'b0, raw_instruction[5]};
      9 /* RELU */        : arith_instr <= {13'b0000000010000, 4'b0, 1'b1};
      10 /* EXP */        : arith_instr <= {13'b0000000001000, 5'b0};
      11 /* LOG */        : arith_instr <= {13'b0000000000100, 5'b0};
      12 /* GTZ */        : arith_instr <= {13'b0000000010000, 4'b0, 1'b0};
      13 /* COPY */       : arith_instr <= {13'b1000000000010, raw_instruction[5:6], raw_instruction[7:8], '0};
      14 /* ZERO */       : arith_instr <= {13'b0000000000001, raw_instruction[5:6], 3'b0};
      15 /* LOAD */       : ld_st_instr <= {raw_instruction[5:7], 1'b1, raw_instruction[8:9], raw_instruction[10:11], raw_instruction[12:13], raw_instruction[14], raw_instruction[15]};
      16 /* STORE */      : ld_st_instr <= {raw_instruction[5:7], 1'b0, raw_instruction[8:9], raw_instruction[10:11], raw_instruction[12:13], raw_instruction[14], raw_instruction[15]};
      17 /* START_INDEPENDENT_LOOP */ : begin
        loop_mux_independent <= 1'b1;
        loop_is_new_loop <= 1'b1;
      end
      18 /* START_LOOP */ :             begin
        loop_mux_independent <= 1'b0;
        loop_is_new_loop <= 1'b1;
      end
      19 /* JUMP_OR_END_LOOP */ :       begin
        loop_mux_independent <= 1'b0;
        loop_is_new_loop <= 1'b0;
      end
    endcase    
  end

loopmux loopmux (
    .addr         (raw_instruction[5:7]),
    .in           (loop_ro_data),
    .independent  (loop_mux_independent),
    .new_loop     (loop_is_new_loop),
    .loop_instr   (loop_instr)
);
endmodule

module loopmux (
    input [2:0] addr,
    input [0:24*8-1] in,
    input independent,
    input new_loop,
    output decoded_loop_instruction loop_instr
);
reg [23:0] out;
//assign out = in[addr*18*6 +: 18*6]; // synthesizes so poorly it uses a DSP lmao
assign loop_instr = {new_loop, out, independent};
always @(*) begin
    case (addr)
        3'd0: out <= in[0*24 +: 24];
        3'd1: out <= in[1*24 +: 24];
        3'd2: out <= in[2*24 +: 24];
        3'd3: out <= in[3*24 +: 24];
        3'd4: out <= in[4*24 +: 24];
        3'd5: out <= in[5*24 +: 24];
        3'd6: out <= in[6*24 +: 24];
        3'd7: out <= in[7*24 +: 24];
    endcase
end
endmodule