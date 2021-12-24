/*
 * 2^x power where x is a floating point
 * If exponent is positive
 *    let k = 0.fraction << exponent # k is a fixed point number with an integer and a fraction
 *    output exponent is (1<<exponent)+floor(k) # the floor operation is a bitselect and the sum is really a vector concatenation
 *    output mantissa is 2^(k-floor(k)) # k-floor(k) is really a bit select
 * Else
 *    let k = 0.fraction >> exponent # k is a fixed point number with just a fraction. 0 <= k < 1
 *    output exponent is 0
 *    output mantissa is 2^((1>>exponent)+k) # the sum is really a bit concatenation
 * The trick for 2^i where i is an integer is to approximate with a cheap polynomial
 */

module ex2(
  input clk,
  input [WIDTH-1:0] in,
  output logic [WIDTH-1:0] out
);
endmodule