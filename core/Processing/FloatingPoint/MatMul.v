// Yosys says 7754 LCs and 64 DSP for N=4
module MatMul (
    input clk,
    input [0:MAT_BITS-1] MAT_A, MAT_B,
    output [0:MAT_BITS-1] MAT_OUT
);
    localparam N = 4;
    localparam width = 18;
    localparam MAT_BITS = width*N*N;
    `define pos(row, col) width*(row*N+col)+:width
    `define row(row) width*(row*N)+:width*N
    genvar i, j, k;
    generate
        for (i = 0; i < N; i++) begin : output_row_loop
            for (j = 0; j < N; j++) begin : output_col_loop
                wire [0:width*N-1] row, col;
                assign row = MAT_A[`row(i)];
                for (k = 0; k < N; k++) begin : get_input_column
                    assign col[width*k +: width] = MAT_B[`pos(k,j)];
                end
                DotProduct#(N) dot_prod_unit(
                    clk, row, col, element_result
                );
                wire [width-1:0] element_result;
                assign MAT_OUT[`pos(i,j)] = element_result;
            end
        end
	endgenerate
endmodule
