/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "varray.sv"

`timescale 1 ns / 100 ps

module varray_testbench();

    `SVUT_SETUP

    parameter VIRTUAL_ELEMENT_WIDTH = 4;
    parameter VIRTUAL_ADDR_BITS = 16;

    reg clk;
    reg reset;
    reg we;
    reg [VIRTUAL_ADDR_BITS-1:0] write_addr;
    reg [3:0] write_addr_len;
    reg [VIRTUAL_ELEMENT_WIDTH-1:0] dat_w;
    reg re;
    reg [VIRTUAL_ADDR_BITS-1:0] read_addr;
    wire [VIRTUAL_ELEMENT_WIDTH-1:0] dat_r;
    wire [VIRTUAL_ADDR_BITS-1:0] varray_len;

    varray 
    #(
    .VIRTUAL_ELEMENT_WIDTH (VIRTUAL_ELEMENT_WIDTH)
    )
    dut 
    (
    .clk            (clk),
    .reset          (reset),
    .we             (we),
    .write_addr     (write_addr),
    .write_addr_len (write_addr_len),
    .dat_w          (dat_w),
    .re             (re),
    .read_addr      (read_addr),
    .dat_r          (dat_r),
    .varray_len     (varray_len)
    );

    // To create a clock:
    initial clk = 0;
    always #2 clk = ~clk;

    // Setup time format when printing with $realtime
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        reset = 1;
        @(posedge clk); #1
        reset = 0;
        we = 0;
        re = 0;
        @(posedge clk);
    end
    endtask

    task teardown(msg="");
    begin
        /// teardown() runs when a test ends
    end
    endtask

    `TEST_SUITE("SUITE_NAME")

    `UNIT_TEST("TEST_NAME")

        we = 1;
        write_addr = 0;
        write_addr_len = 2;
        dat_w = 4'd12;
        @(posedge clk); #1
        we = 0;
        re = 1;
        read_addr = 0;
        @(posedge clk); #1
        `ASSERT((dat_r == 4'd12));
        read_addr = 1;
        @(posedge clk); #1
        `ASSERT((dat_r == 4'd12));
        `ASSERT((varray_len == 2));
        read_addr = 2;
        we = 1;
        write_addr = 10;
        write_addr_len = 3;
        dat_w = 4'd6;
        @(posedge clk); #1
        we = 0;
        `ASSERT((varray_len == 13));
        @(posedge clk); #1
        @(posedge clk); #1
        re = 1;
        read_addr = 10;
        @(posedge clk); #1
        `ASSERT((dat_r == 4'd6));
        read_addr = 11;
        @(posedge clk); #1
        `ASSERT((dat_r == 4'd6));
        read_addr = 12;
        @(posedge clk); #1
        `ASSERT((dat_r == 4'd6));
        `ASSERT((varray_len == 13));
        

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
