module DotProduct (
    input clk,
    input [VECTOR_BITS-1:0] A, B,
    output [WIDTH-1:0] OUT
);
parameter CNT = 4;
localparam WIDTH = 18;
localparam VECTOR_BITS = WIDTH*CNT;
wire [VECTOR_BITS-1:0] intermediate_vector;

// Element wise multiply
Mul mul_unit[CNT-1:0] (A, B, intermediate_vector);

// Sum Reduce
GroupSum GroupSum (
  clk,
  intermediate_vector,
  OUT
);

endmodule