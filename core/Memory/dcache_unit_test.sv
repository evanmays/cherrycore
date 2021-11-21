/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "dcache.sv"

`timescale 1 ns / 100 ps

module dcache_testbench();

    `SVUT_SETUP

    reg clk;
    reg [1:0]     write_slot, read_slot;
    reg [10:0]    write_addr, read_addr;
    reg we, re;
    reg [17:0]    dat_w;
    logic  [17:0]    dat_r;
    logic read_complete;

    dcache
    dut
    (
    .clk(clk),
    .dma_write_port({write_slot, write_addr, we, dat_w}),
    .dma_read_port_in({read_slot, read_addr, re}),
    .dma_read_port_out({dat_r, read_complete})
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
        // write
        write_slot = 2'd2;
        write_addr = 11'd0;
        we = 1;
        dat_w = 18'd3423;
        re = 0;
        @(posedge clk); #1
        `ASSERT((read_complete === 0));
        `ASSERT((dut.single_tile_slot === dat_w));

        // read
        we = 0;
        dat_w = 18'd1337;
        re = 1;
        read_addr = 11'd0;
        read_slot = 2'd2;
        @(posedge clk); #1
        `ASSERT((dat_r === 18'd3423));
        `ASSERT((read_complete === 1));

        // write and read
        we = 1;
        re = 1;
        read_addr = 11'd0;
        @(posedge clk); #1
        `ASSERT((dat_r === 18'd3423));
        `ASSERT((read_complete === 1));

        // read
        we = 0;
        re = 1;
        @(posedge clk); #1
        `ASSERT((dat_r === 18'd1337));
        `ASSERT((read_complete === 1));

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
