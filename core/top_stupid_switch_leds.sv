// Useful for testing if you can upload verilog to your fpga correctly
module top_stupid_switch_leds(
  input sys_clk,
  input [3:0] sw,
  output [3:0] led
);
reg [25:0] num;
always @(posedge sys_clk) begin
  num <= sw[0] ? 0 : num + 1; // reset or increment
end

assign led[0] = |sw;
assign led[1] = &sw;
assign led[2] = num[25]; // blinking
endmodule