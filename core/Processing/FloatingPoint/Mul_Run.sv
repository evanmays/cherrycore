// takes in two fp32. casts them to tf32/cherry_float/bf16, does multiplication, casts result back to fp32 and returns
// fp32 input and output must be hexadecimal

`include "Mul.v"

`timescale 1 ns / 100 ps

module Mul_run();

    logic [17:0] cherry_float_A,    cherry_float_B,     cherry_float_ret;
    logic [18:0] tf32_A,            tf32_B,             tf32_ret;
    logic [15:0] bf16_A,            bf16_B,             bf16_ret;

    Mul #(9)    cherry_float_dut    ( cherry_float_A,   cherry_float_B,     cherry_float_ret );
    Mul #(10)   tf32_dut            ( tf32_A,           tf32_B,             tf32_ret );
    Mul #(7)    bf16_dut            ( bf16_A,           bf16_B,             bf16_ret );

    logic clk;

    initial clk = 0;
    always #2 clk = ~clk;


    function  bit[18:0] tf32 (bit[31:0] x);
		tf32 = x[31 -: 19];
	endfunction
    function  bit[18:0] bf16 (bit[31:0] x);
		bf16 = x[31 -: 16];
	endfunction
    function  bit[18:0] cherry_float (bit[31:0] x);
		cherry_float = x[31 -: 18];
	endfunction
    function  bit[31:0] tf32_to_fp32 (bit[18:0] tf32);
        tf32_to_fp32 = tf32 << 13;
    endfunction
    function  bit[31:0] bf16_to_fp32 (bit[15:0] bf16);
        bf16_to_fp32 = bf16 << 16;
    endfunction
    function  bit[31:0] cherry_float_to_fp32 (bit[18:0] cherry_float);
        cherry_float_to_fp32 = cherry_float << 14;
    endfunction

    logic [31:0] a, b;
    integer mulType;
    bool readA, readB, readMulType;
    initial begin
        readA = $value$plusargs ("a=%h", a);
        readB = $value$plusargs ("b=%h", b);
        readMulType = $value$plusargs ("type=%d", mulType);
        if (readA && readB && readMulType) begin
            case (mulType)
                0 : begin
                    tf32_A = tf32(a);
                    tf32_B = tf32(b);
                    @(posedge clk); #1
                    $display("ret %x", tf32_to_fp32(tf32_ret));
                end
                1 : begin
                    bf16_A = bf16(a);
                    bf16_B = bf16(b);
                    @(posedge clk); #1
                    $display("ret %x", bf16_to_fp32(bf16_ret));
                end
                2 : begin
                    cherry_float_A = cherry_float(a);
                    cherry_float_B = cherry_float(b);
                    @(posedge clk); #1
                    $display("ret %x", cherry_float_to_fp32(cherry_float_ret));
                end
            endcase
            
        end
        else begin
            if (!readA) begin
                $display ("Missing +a=");
            end
            if (!readB) begin
                $display ("Missing +b=");
            end
            if (!readMulType) begin
                $display ("Missing +type=");
            end
        end
        $finish;
    end
endmodule
