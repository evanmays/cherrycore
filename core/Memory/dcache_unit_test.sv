/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "dcache.sv"

`timescale 1 ns / 100 ps

module dcache_testbench();

    `SVUT_SETUP

    reg clk;
    reg [1:0]     dma_slot;
    reg [10:0]    dma_addr;
    reg dma_we;
    reg [17:0]    dma_dat_w;
    reg dma_re;
    logic  [17:0]    dma_dat_r;
    logic dma_dcache_read_complete;

    dcache
    dut
    (
    clk,
    dma_slot,
    dma_addr,
    dma_we,
    dma_dat_w,
    dma_re,
    dma_dat_r,
    dma_dcache_read_complete
    );

    // To create a clock:
    initial clk = 0;
    always #2 clk = ~clk;

    // To dump data for visualization:
    // initial begin
    //     $dumpfile("single_dcache_mem_testbench.vcd");
    //     $dumpvars(0, single_dcache_mem_testbench);
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

    `TEST_SUITE("SUITE_NAME")

    `UNIT_TEST("BASIC_TEST")
        dma_slot = 2'd2;
        dma_addr = 11'd0;
        dma_we = 1;
        dma_dat_w = 18'd3423;
        dma_re = 0;
        @(posedge clk); #1
        `ASSERT((dma_dcache_read_complete === 0));

        dma_we = 0;
        dma_dat_w = 18'd1337;
        dma_re = 1;
        @(posedge clk); #1
        `ASSERT((dma_dat_r === 18'd3423));
        `ASSERT((dma_dcache_read_complete === 1));

        dma_we = 1;
        dma_re = 0;
        @(posedge clk); #1
        `ASSERT((dma_dat_r === 18'd3423));
        `ASSERT((dma_dcache_read_complete === 0));

        dma_we = 0;
        dma_re = 1;
        @(posedge clk); #1
        `ASSERT((dma_dat_r === 18'd1337));
        `ASSERT((dma_dcache_read_complete === 1));

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
