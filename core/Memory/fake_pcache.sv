module fake_icache (
  input     [15:0]  pc,
  output  logic  [15:0]  raw_instruction
);
  always @(*) begin
    case (pc)
      16'd6: raw_instruction = 16'hf000; // start_loop (independent) // use 16'hd000 for non-independent loop
      16'd7: raw_instruction = 16'h4080; // cisa_mem_read
      16'd8: raw_instruction = 16'h2000; // cisa_load
      16'd9: raw_instruction = 16'h8000; // cisa_relu
      16'd10: raw_instruction = 16'h0180; // cisa_store
      16'd11: raw_instruction = 16'h6120; // cisa_mem_write
      16'd12: raw_instruction = 16'hc000; // end_loop_or_jump
      default: raw_instruction = 16'h8000;
    endcase
  end
endmodule

module fake_ro_data (
  input addr,
  output logic [0:4*9*18-1] prog_apu_formula,
  output logic [24*8-1:0]   prog_loop_ro_data
);

always @(*) begin
  case (addr)
    0: begin
      prog_apu_formula = 648'h000040000000000000000000000000000000000000001000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000;
      prog_loop_ro_data = 192'h002006000000000000000000000000000000000000000000;
    end
    1: begin
      prog_apu_formula = 648'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
      prog_loop_ro_data = 0;
    end
    default: begin
      prog_apu_formula = 0;
      prog_loop_ro_data = 0;
    end
  endcase
end
  
endmodule