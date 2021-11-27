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