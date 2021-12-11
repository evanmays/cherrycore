/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "GroupSum.sv"

`timescale 1 ns / 100 ps

module GroupSum_testbench();

    `SVUT_SETUP

    reg clk;
    logic [4*18-1:0]  array_in;
    logic [18-1:0] ret;
    GroupSum 
    dut 
    (
    .clk      (clk),
    .array_in (array_in),
    .sum(ret)
    );

    // To create a clock:
    initial clk = 0;
    always #2 clk = ~clk;

    // To dump data for visualization:
    // initial begin
    //     $dumpfile("GroupSum_testbench.vcd");
    //     $dumpvars(0, GroupSum_testbench);
    // end

    // Setup time format when printing with $realtime
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        /// setup() runs when a test begins
    end
    endtask

    task teardown(msg="");
    begin
        /// teardown() runs when a test ends
    end
    endtask

    function  bit[17:0] cherry_float (bit[31:0] x);
		cherry_float = x[31 -: 18];
	endfunction

    `TEST_SUITE("SUITE_NAME")

    `UNIT_TEST("SIMPLE_ADD")
        array_in = {{2{cherry_float(32'h3f800000)}}, {2{cherry_float(32'h40000000)}}}; // [1.0, 1.0, 2.0, 2.0]. but 0 index on right.
        @(posedge clk); #2
        `ASSERT((dut.E_max_1 === 128));
        @(posedge clk); #2
        `ASSERT((dut.exponent_2 == 128));
        `ASSERT((dut.shift_amount_2[0] === 0));
        `ASSERT((dut.shift_amount_2[1] === 0));
        `ASSERT((dut.shift_amount_2[2] === 1));
        `ASSERT((dut.shift_amount_2[3] === 1));
        for (int i = 0; i < 4; i += 1) begin
            `ASSERT((dut.fraction_array_2[i] === 9'b000000000));
        end
        @(posedge clk); #2
        `ASSERT((dut.signed_mantissa_array_3[0] === 11'b01000000000));
        `ASSERT((dut.signed_mantissa_array_3[1] === 11'b01000000000));
        `ASSERT((dut.signed_mantissa_array_3[2] === 11'b00100000000));
        `ASSERT((dut.signed_mantissa_array_3[3] === 11'b00100000000));
        `ASSERT((dut.exponent_3 === 128));
        @(posedge clk); #2
        `ASSERT((dut.mantissa_4 === 13'b0011000000000));
        `ASSERT((dut.exponent_4 === 128));
        @(posedge clk); #2
        $display("%b", dut.mantissa_5);
        `ASSERT((dut.mantissa_5 === 13'b0011000000000));
        `ASSERT((dut.exponent_5 === 128));
        $display("%d %d", dut.fraction_array_2[1], dut.exponent_5);
        @(posedge clk); #2
        `ASSERT((dut.fraction_6 === 9'b100000000));
        `ASSERT((dut.exponent_6 === 129));
        `ASSERT((dut.sign_6 === 0));
        $display("%b %d", dut.mantissa_5, dut.exponent_6);
    `UNIT_TEST_END

    `UNIT_TEST("SIMPLE_ADD_SUB")
        array_in = {cherry_float(32'h3f800000),cherry_float(32'hbf800000), {2{cherry_float(32'h40000000)}}}; // [1.0, -1.0, 2.0, 2.0]. but 0 index on right.
        @(posedge clk); #2
        `ASSERT((dut.E_max_1 === 128));
        @(posedge clk); #2
        `ASSERT((dut.exponent_2 == 128));
        `ASSERT((dut.shift_amount_2[0] === 0));
        `ASSERT((dut.shift_amount_2[1] === 0));
        `ASSERT((dut.shift_amount_2[2] === 1));
        `ASSERT((dut.shift_amount_2[3] === 1));
        `ASSERT((dut.fraction_array_2[0] === 9'b000000000));
        `ASSERT((dut.fraction_array_2[1] === 9'b000000000));
        `ASSERT((dut.fraction_array_2[2] === 9'b000000000));
        `ASSERT((dut.fraction_array_2[3] === 9'b000000000));
        @(posedge clk); #2
        `ASSERT((dut.signed_mantissa_array_3[0] === 11'b01000000000));
        `ASSERT((dut.signed_mantissa_array_3[1] === 11'b01000000000));
        `ASSERT((dut.signed_mantissa_array_3[2] === 11'b11100000000));
        `ASSERT((dut.signed_mantissa_array_3[3] === 11'b00100000000));
        `ASSERT((dut.exponent_3 === 128));
        @(posedge clk); #2
        
        `ASSERT((dut.mantissa_4 === 13'b0010000000000));
        `ASSERT((dut.exponent_4 === 128));
        @(posedge clk); #2
        // $display("%b", dut.mantissa_5);
        `ASSERT((dut.mantissa_5 === 13'b0010000000000));
        `ASSERT((dut.exponent_5 === 128));
        $display("%d %d", dut.fraction_array_2[1], dut.exponent_5);
        @(posedge clk); #2
        `ASSERT((dut.fraction_6 === 9'b000000000));
        `ASSERT((dut.exponent_6 === 129));
        `ASSERT((dut.sign_6 === 0));
        $display("%b %d", dut.mantissa_5, dut.exponent_6);
    `UNIT_TEST_END


    `UNIT_TEST("LESS_SIMPLE_ADD")
        array_in = {{2{cherry_float(32'h3f9d70a4)}}, {2{cherry_float(32'h403f5c29)}}}; // [1.23, 1.23, 2.99, 2.99]. but 0 index on right.
        repeat(6)
            @(posedge clk); #2
        `ASSERT((dut.fraction_6 === 9'b000011011)); //off by .02? cost of lost lost precision i guess
        `ASSERT((dut.exponent_6 === 130));
        `ASSERT((dut.sign_6 === 0));
        $display("%b %d", dut.fraction_6, dut.exponent_6);
    `UNIT_TEST_END

    `UNIT_TEST("LESS_SIMPLE_ADD_SUB")
        array_in = {cherry_float(32'h3f9d70a4), cherry_float(32'hbf9d70a4), cherry_float(32'h403f5c29), cherry_float(32'hc03f5c29)}; // [1.23, -1.23, 2.99, -2.99]. but 0 index on right.
        repeat(6)
            @(posedge clk); #2
        `ASSERT((dut.fraction(ret) === 0)); //off by .02? cost of lost lost precision i guess
        `ASSERT((dut.exponent(ret) === 0));
        `ASSERT((dut.sign(ret) === 0));
        
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
