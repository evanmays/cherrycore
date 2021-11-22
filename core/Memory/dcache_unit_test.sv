/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "../types.sv"
`include "dcache.sv"

`timescale 1 ns / 100 ps

module dcache_testbench();

    `SVUT_SETUP

    reg clk;
    logic reset, freeze;
    dma_stage_1_instr read_instr;
    dma_stage_2_instr exec_instr;
    dma_stage_3_instr write_instr;
    logic we, re;

    dcache
    dut
    (
    .clk(clk),
    .dma_read_port_in(read_instr),
    .dma_read_port_out(exec_instr),
    .dma_write_port(write_instr),
    .freeze(freeze),
    .reset(reset)
    );

    // To create a clock:
    initial clk = 0;
    always #2 clk = ~clk;

    // To dump data for visualization:
    // initial begin
    //     $dumpfile("single_dcache_mem_testbench.vcd");
    //     $dumpvars(0, single_dcache_mem_testbench);
    // end

    task set_we(on);
    begin
        write_instr.raw_instr_data.mem_we = !on;
    end
    endtask
    task set_re(on);
    begin
        read_instr.raw_instr_data.mem_we = on;
    end
    endtask
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
        freeze = 0;
        reset = 0;

        // write
        write_instr.raw_instr_data.valid = 1'd1;
        write_instr.raw_instr_data.cache_slot = 2'd2;
        write_instr.raw_instr_data.cache_addr = 2'd2;
        set_we(1);
        write_instr.dat = 18'd3423;
        set_re(0);
        @(posedge clk); #1
        `ASSERT((exec_instr.raw_instr_data === read_instr.raw_instr_data));
        `ASSERT((dut.single_tile_slot === write_instr.dat));

        // read
        set_we(0);
        write_instr.dat = 18'd1337;
        set_re(1);
        read_instr.raw_instr_data.valid = 1'd1;
        read_instr.raw_instr_data.cache_slot = 2'd2;
        read_instr.raw_instr_data.cache_addr = 11'd0;
        @(posedge clk); #1
        `ASSERT((exec_instr.dat === 18'd3423));
        `ASSERT((exec_instr.raw_instr_data === read_instr.raw_instr_data));

        // write and read
        set_we(1);
        set_re(1);
        read_instr.raw_instr_data.cache_addr = 11'd0;
        @(posedge clk); #1
        `ASSERT((exec_instr.dat === 18'd3423));
        `ASSERT((exec_instr.raw_instr_data === read_instr.raw_instr_data));

        // read
        set_we(0);
        set_re(1);
        @(posedge clk); #1
        `ASSERT((exec_instr.dat === 18'd1337));
        `ASSERT((exec_instr.raw_instr_data === read_instr.raw_instr_data));

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
