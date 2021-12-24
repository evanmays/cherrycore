
// I look at https://github.com/dawsonjon/fpu/blob/master/multiplier/multiplier.v
// I make combinatorial and parameterize
// It's like 250MHz if you clock it with just one stage!
module Mul (
    input      [WIDTH-1:0] A, B,
    output     [WIDTH-1:0] OUT
);
    localparam EXPONENT = 8; // dont change. Not fully parameterized
    parameter MANTISSA = 9; // default to cherry float
    localparam WIDTH = EXPONENT+MANTISSA+1;
    localparam MAX_EXPONENT = {(EXPONENT){1'b1}};

    // Unpack
    wire                A_s, B_s;
    wire [EXPONENT-1:0] A_e, B_e;
    wire [MANTISSA-1:0] A_f, B_f;
    assign A_s = A[WIDTH-1];
    assign B_s = B[WIDTH-1];
    assign A_e = A[WIDTH-2:MANTISSA];
    assign B_e = B[WIDTH-2:MANTISSA];
    assign A_f = A[MANTISSA-1:0]; 
    assign B_f = B[MANTISSA-1:0];
    wire A_exponent_is_max = A_e == {EXPONENT{1'b1}}; // A_e == {1'b0,{(EXPONENT-1){1'b1}}};
    wire B_exponent_is_max = B_e == {EXPONENT{1'b1}}; // B_e == {1'b0,{(EXPONENT-1){1'b1}}};
    wire A_exponent_is_min = A_e == {EXPONENT{1'b0}}; // A_e == {EXPONENT{1'b1}};
    wire B_exponent_is_min = B_e == {EXPONENT{1'b0}}; // B_e == {EXPONENT{1'b1}};
    wire A_is_zero = A_exponent_is_min; // flush to zero enabled // && A[MANTISSA-1:1] == 0;
    wire B_is_zero = B_exponent_is_min; // flush to zero enabled && B[MANTISSA-1:1] == 0;
    wire A_is_inf = A_exponent_is_max && A_f == 0;
    wire B_is_inf = B_exponent_is_max && B_f == 0;
    wire A_is_nan = A_exponent_is_max && A_f != 0;
    wire B_is_nan = B_exponent_is_max && B_f != 0;
    // wire A_is_underflowed = A_exponent_is_min && A_f != 0; // lets just flush to zero so this line isn't needed
    // wire B_is_underflowed = B_exponent_is_min && B_f != 0; // lets just flush to zero so this line isn't needed

    // Special cases checks in parallel
    wire should_return_inf = (A_is_inf && !B_is_zero) || (B_is_inf && !A_is_zero);
    wire should_return_nan = (A_is_nan || B_is_nan) || (A_is_inf && B_is_zero)|| (B_is_inf && A_is_zero);
    wire should_return_zero = A_is_zero || B_is_zero;

    // Math
    wire [(MANTISSA+1)*2-1:0] pre_prod_frac;
    assign pre_prod_frac = {1'b1, A_f} * {1'b1, B_f};
    // assign pre_prod_frac = {A_is_underflowed ? 1'b0 : 1'b1, A_f} * {B_is_underflowed ? 1'b0 : 1'b1, B_f}; // In vivado default synth/impl, on fp32 checking for underflows costs us 20 LUTs and on cherry float 9 LUTs. I didn't even try normalizing the number after.

    wire [EXPONENT:0] pre_prod_exp;
    assign pre_prod_exp = $signed(A_e - 127) + $signed(B_e - 127); // add 1?

    // If MSB of product frac is 1, shift right one. Else if second MSB is 0, shift left one
    // TODO: Do we need rounding when we cut the bits off? Or is it ok to always round down in AI?
    wire [EXPONENT:0] intermediate_Prod_e;
    wire [EXPONENT-1:0] oProd_e = intermediate_Prod_e + 127;
    wire [MANTISSA-1:0] oProd_f;
    wire need_mantissa_left_shift = pre_prod_frac[(MANTISSA+1)*2-2];
    wire need_mantissa_right_shift = pre_prod_frac[(MANTISSA+1)*2-1];
    assign intermediate_Prod_e = need_mantissa_right_shift
        ? (pre_prod_exp+1'b1)
        // : need_mantissa_left_shift
        //     ? (pre_prod_exp-1'b1)
            : (pre_prod_exp);
    assign oProd_f = need_mantissa_right_shift
        ? pre_prod_frac[(MANTISSA+1)*2-2 -:MANTISSA]
        // : need_mantissa_left_shift
        //     ? pre_prod_frac[(MANTISSA+1)*2-3:MANTISSA]
            : pre_prod_frac[(MANTISSA+1)*2-3 -:MANTISSA];

    // Detect underflow
    wire underflow = $signed(intermediate_Prod_e) < -126;  // is this synthesizing properly?
    wire overflow  = $signed(intermediate_Prod_e) > 128;

    // Should special cases come first?
    assign OUT =   should_return_nan                ? {1'b1, MAX_EXPONENT, 1'b1, {(MANTISSA-1){1'b0}}} :
                   underflow | should_return_zero   ? {A_s ^ B_s, {(WIDTH-1){1'b0}}} :
                   should_return_inf | overflow     ? {A_s ^ B_s, MAX_EXPONENT, {MANTISSA{1'b0}}} :
                   {A_s ^ B_s, oProd_e, oProd_f};

endmodule
