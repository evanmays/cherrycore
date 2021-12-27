module UnopALU (
  input wire [LEN*18-1:0] vector_in,
  output wire [LEN*18-1:0] vector_out
);
parameter LEN=4*4;

for (genvar i = 0; i < LEN; i = i + 1) begin
  assign vector_out[i*18 +: 18] = relu(vector_in[i*18 +: 18]);
end

function [17:0] relu;
	input [17:0] a;
	begin
		relu = a[17] ? 18'd0 : a;
	end
endfunction

endmodule