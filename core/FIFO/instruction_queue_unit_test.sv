/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "../types.sv"
`include "../ControlUnit/types.sv"
`include "instruction_queue.sv"

`timescale 1 ns / 100 ps

module instruction_queue_testbench();

    `SVUT_SETUP
    parameter LOG_SUPERSCALAR_WIDTH = 3;
    reg reset;
    reg clk;
    reg re;
    dma_instruction        dma_instr;
    arithmetic_instruction arithmetic_instr;
    regfile_instruction    cache_instr;
    logic                   empty;
    
    logic we;
    logic [1:0]        instr_type;
    logic  [17:0] cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr;
    logic [0:13] in_arith_instr;
    logic [0:8]  in_ram_instr;
    logic [0:9]  in_ld_st_instr;
    reg [LOG_SUPERSCALAR_WIDTH:0]       copy_count;

    instruction_queue 
    dut 
    (
    reset,
    clk,
    re,
    dma_instr,
    arithmetic_instr,
    cache_instr,
    empty,
    we,
    instr_type,
    copy_count,
    cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr,
    in_arith_instr, in_ram_instr, in_ld_st_instr
    );

    // To create a clock:
    initial clk = 0;
    always #2 clk = ~clk;

    // Setup time format when printing with $realtime
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        /// setup() runs when a test begins
        reset = 1;
        @(posedge clk); #1
        reset = 0;
        @(posedge clk); #1
        $display("reset");
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
        in_arith_instr = 20;
        instr_type = INSTR_TYPE_ARITHMETIC;
        copy_count = 1; // remember this is off by 1. so 1 is really saying give me 2 copies
        @(posedge clk); #1
        we = 0;
        @(posedge clk); #1
        re = 1;
        @(posedge clk); #1
        `ASSERT((arithmetic_instr === 20));
        @(posedge clk); #1
        `ASSERT((arithmetic_instr === 20));
        re = 0;
        @(posedge clk); #1
        `ASSERT((arithmetic_instr === 20));
        we = 1;
        in_ram_instr = 45;
        instr_type = INSTR_TYPE_RAM;
        copy_count = 1;
        @(posedge clk); #1
        $display("ok %d", dut.dma_queue[6]);
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
