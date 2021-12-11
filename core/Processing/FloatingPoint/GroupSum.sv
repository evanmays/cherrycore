// This module takes a list of cherry floats and sums them
// Using ideas from the paper Group-Alignment based Accurate Floating-Point Summation on FPGAs. by Guan Qin and Mi Lu
// Appears to scale LUT usage linearly with size. Clock scales better than linear. Can we run 6 stages with size=8 or size=16 on cherry 1?
module GroupSum (
  input                   clk,
  input [size*WIDTH-1:0]  array_in,
  output[WIDTH-1:0]       sum
);

// dont edit these
localparam logsize = 2;
localparam size = 4;
localparam EXPONENT = 8; // needs to be < fraction
localparam MAX_EXPONENT = {(EXPONENT){1'b1}};
localparam MIN_EXPONENT = {(EXPONENT){1'b0}};
localparam FRACTION = 9;
localparam MANTISSA = FRACTION + 1;
localparam SIGNED_MANTISSA = MANTISSA + 1;
localparam WIDTH = EXPONENT+FRACTION+1;

reg exponent_is_max [0:size-1];
reg exponent_is_min [0:size-1];
generate
  for (genvar i = 0; i < size; i = i + 1) begin
    always @(*) begin
      exponent_is_max[i] = exponent(array_in[i*WIDTH +: WIDTH]) == MAX_EXPONENT;
      exponent_is_min[i] = exponent(array_in[i*WIDTH +: WIDTH]) == MIN_EXPONENT;
    end
  end
endgenerate

//
//
// Pipelined implementation of Group-alignment based FP summation (Algorithm 1 from the paper mentioned above)
//
//

//
// Stage 1: Find largest exponent and calc if should return nan
//
reg [EXPONENT-1:0] E_max_1;
reg [WIDTH-1:0] input_array_1 [0:size-1];
reg             should_return_nan_1; // todo: Also need checks for -inf+inf. If 2 inf appear that aren't the same sign.
always @(posedge clk) begin
  E_max_1 = exponent(array_in[0 +: WIDTH]);
  should_return_nan_1 = exponent_is_max[0] & fraction(array_in[0 +: WIDTH]) !== 0;
  for (integer i=1; i<size; i++) begin
    if (exponent(array_in[i*WIDTH +: WIDTH]) > E_max_1)
      E_max_1 = exponent(array_in[i*WIDTH +: WIDTH]);
    should_return_nan_1 = should_return_nan_1 | (exponent_is_max[i] & fraction(array_in[i*WIDTH +: WIDTH]) !== 0);
  end
end
generate
  for (genvar i = 0; i < size ; i = i + 1) begin
    always @(posedge clk) begin
      input_array_1[i] <= array_in[i*WIDTH +: WIDTH];
    end
  end
endgenerate

//
// Stage 2: Calculate every E_max - E_i
//
logic [EXPONENT-1:0] shift_amount_2 [0:size-1];
reg [FRACTION-1:0] fraction_array_2 [0:size-1];
reg                sign_array_2 [0:size-1];
reg [EXPONENT-1:0] exponent_2;
reg               should_return_nan_2;
generate
  for(genvar i = 0; i < size; i = i + 1) begin
    always @(posedge clk) begin
      shift_amount_2[i] <= E_max_1 - exponent(input_array_1[i]);
      fraction_array_2[i] <= fraction(input_array_1[i]);
      sign_array_2[i] <= sign(input_array_1[i]);
    end
  end
endgenerate
always @(posedge clk) begin
  exponent_2 <= E_max_1;  
  should_return_nan_2 <= should_return_nan_1;
end

// Stage 3: Shift each M_i by (E_max - E_i) bits right then conver to twos complement if F_i was negative
reg [MANTISSA-1:0] intermediate_mantissa_array_3 [0:size-1];
reg signed [SIGNED_MANTISSA-1:0] signed_mantissa_array_3 [0:size-1];
reg [EXPONENT-1:0] exponent_3;
reg               should_return_nan_3;
generate
  for(genvar i = 0; i < size; i = i + 1) begin
    always @(*)
      intermediate_mantissa_array_3[i] = ({1'b1, fraction_array_2[i]} >> shift_amount_2[i]);
    always @(posedge clk) begin
      signed_mantissa_array_3[i]
        <= sign_array_2[i] ? (~(intermediate_mantissa_array_3[i]) + 1'b1) : {1'b0, intermediate_mantissa_array_3[i]};
    end
  end
endgenerate
always @(posedge clk) begin
  exponent_3 <= exponent_2;
  should_return_nan_3 <= should_return_nan_2;
end

// Stage 4: Sum each shifted M_i
parameter SIGNED_MANTISSA_SUM_WIDTH = SIGNED_MANTISSA + 2; // 3 sums produces 2 extra bits.
reg signed [SIGNED_MANTISSA_SUM_WIDTH - 1:0] intermediate_signed_mantissa_4;
reg signed [SIGNED_MANTISSA_SUM_WIDTH - 1:0] mantissa_4; //todo: rename to add signed_ prefix
reg [EXPONENT-1:0] exponent_4;
reg               should_return_nan_4;
always @(*) begin
  intermediate_signed_mantissa_4 = 0;
  for (int i=0; i<size; i++)
    intermediate_signed_mantissa_4 += signed_mantissa_array_3[i];
end
always @(posedge clk) begin
  exponent_4 <= exponent_3;
  mantissa_4 <= intermediate_signed_mantissa_4;
  should_return_nan_4 <= should_return_nan_3;
end

// Stage 5: Count leading 0 and unsign the mantissa
reg Break;

reg [3:0] intermediate_leading_zero_count_5; // width is log2(MANTISSA_SUM_WIDTH)
reg [3:0] leading_zero_count_5;
reg [SIGNED_MANTISSA_SUM_WIDTH - 1:0] mantissa_5;
reg [EXPONENT-1:0] exponent_5;
reg                output_sign_5;
reg               should_return_nan_5;
wire [SIGNED_MANTISSA_SUM_WIDTH - 1:0] mantissa_4_unsigned = mantissa_4[12] ? ~(mantissa_4 - 1'b1) : mantissa_4;
always @(*) begin
  // inferred
  // intermediate_leading_zero_count_5 = 4'd0;
  // Break = 0;
  // for (int i = MANTISSA_SUM_WIDTH - 1; i >= 0; i = i - 1) begin
  //   if (mantissa_4[i])
  //     Break = 1;
  //   else
  //     if (!Break) intermediate_leading_zero_count_5 = intermediate_leading_zero_count_5 + 1'b1;
  // end

  // manual (yosys needs this. Would vivado do better?)
  intermediate_leading_zero_count_5 = mantissa_4_unsigned[12] ? 0 : mantissa_4_unsigned[11] ? 1 : mantissa_4_unsigned[10] ? 2 : mantissa_4_unsigned[9] ? 3 : mantissa_4_unsigned[8] ? 4 : mantissa_4_unsigned[7] ? 5 : mantissa_4_unsigned[6] ? 6 : mantissa_4_unsigned[5] ? 7 : mantissa_4_unsigned[4] ? 8 : mantissa_4_unsigned[3] ? 9 : mantissa_4_unsigned[2] ? 10 : mantissa_4_unsigned[1] ? 11 : mantissa_4_unsigned[0] ? 12 : 13;
end
always @(posedge clk) begin
  exponent_5 <= exponent_4;
  output_sign_5 <= mantissa_4[12];
  mantissa_5 <= mantissa_4_unsigned;
  leading_zero_count_5 <= intermediate_leading_zero_count_5;
  should_return_nan_5 <= should_return_nan_4;
end

// Stage 6: Normalize the float and do special condition checks
reg [FRACTION-1:0] fraction_6;
reg [EXPONENT-1:0] exponent_6;
reg                sign_6;
reg               should_return_nan_6;
always @(posedge clk) begin
  sign_6 <= output_sign_5;
  should_return_nan_6 <= should_return_nan_5;
  if (leading_zero_count_5 > 4'd3) begin // could also do >= 3
    fraction_6 <= mantissa_5[9:0] << (4'd13 - leading_zero_count_5);
    exponent_6 <= exponent_5 - (4'd13 - leading_zero_count_5);
  end else begin
    // mantissa_5[MANTISSA_SUM_WIDTH - 1 - leading_zero_count_5 - 1 -: FRACTION]; // mux inferred
    fraction_6 <= mantissa_5[12] ? mantissa_5[3+:FRACTION] : mantissa_5[11] ? mantissa_5[2+:FRACTION] : mantissa_5[10] ? mantissa_5[1+:FRACTION] : mantissa_5[0+:FRACTION];// mux manual
    exponent_6 <= exponent_5 + (4'd3 - leading_zero_count_5);
  end
end

wire should_return_zero = fraction_6 == 0;
assign sum =  should_return_nan_6 ? {1'b1, MAX_EXPONENT, 1'b1, {(FRACTION-1){1'b0}}} :
              // should_return_inf ? {A_s ^ B_s, MAX_EXPONENT, {FRACTION{1'b0}}} :
              should_return_zero  ? {sign_6, MIN_EXPONENT, {FRACTION{1'b0}}} :
                                    {sign_6, exponent_6, fraction_6};

function sign (input [WIDTH-1:0] f); begin sign = f[WIDTH-1]; end endfunction
function [EXPONENT-1:0] exponent (input [WIDTH-1:0] f); begin exponent = f[WIDTH-2 -: EXPONENT]; end endfunction
function [FRACTION-1:0] fraction (input [WIDTH-1:0] f); begin fraction = f[FRACTION-1 -: FRACTION]; end endfunction
endmodule