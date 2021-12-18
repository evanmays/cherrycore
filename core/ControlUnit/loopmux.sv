module loopmux (
    input [2:0] addr,
    // verilator lint_off LITENDIAN
    input [0:24*8-1] in,
    // verilator lint_on LITENDIAN
    input independent,
    input new_loop,
    output decoded_loop_instruction loop_instr
);
reg [23:0] out;
//assign out = in[addr*18*6 +: 18*6]; // synthesizes so poorly it uses a DSP lmao
assign loop_instr = {new_loop, out, independent, addr};
always @(*) begin
    case (addr)
        3'd0: out = in[0*24 +: 24];
        3'd1: out = in[1*24 +: 24];
        3'd2: out = in[2*24 +: 24];
        3'd3: out = in[3*24 +: 24];
        3'd4: out = in[4*24 +: 24];
        3'd5: out = in[5*24 +: 24];
        3'd6: out = in[6*24 +: 24];
        3'd7: out = in[7*24 +: 24];
    endcase
    `ifdef FORMAL
        assert(loop_instr.name == addr);
        assert(loop_instr.is_independent == independent);
        assert(loop_instr.iteration_count    == in[addr*24      +: 18]); // assembler.py says pack('uint:18, uint:6', iteration_count, jump_amount)
        assert(loop_instr.jump_amount        == in[addr*24+18   +: 6]);  // if this could be pulled from assembler.py that would be nice. I want them to always be in sync
        assert(loop_instr.is_new_loop == new_loop);
    `endif
end
endmodule