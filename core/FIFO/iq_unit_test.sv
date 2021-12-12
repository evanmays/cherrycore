`include "svut_h.sv"
`include "../types.sv"
`include "../ControlUnit/types.sv"
`include "varray.sv"
`include "iq.sv"

`timescale 1 ns / 100 ps

module instruction_queue_testbench();

    `SVUT_SETUP
    localparam [3:0] LOG_SUPERSCALAR_WIDTH = 4;
    logic                   reset;
    logic                   clk;
    logic                  re;
    dma_instruction        out_dma_instr;
    math_instr             out_math_instr;
    regfile_instruction    out_cache_instr;
    logic                  empty;
    logic                                   we;
    logic [1:0]                             in_instr_type;
    logic [LOG_SUPERSCALAR_WIDTH:0]       copy_count;
    logic [17:0]                            cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr;
    logic [0:9]                             in_arith_instr;
    logic [0:8]                             in_ram_instr;
    logic [0:9]                             in_ld_st_instr;
    logic                                  needs_reset;

    instruction_queue 
    dut 
    (
    .reset           (reset),
    .clk             (clk),
    .re              (re),
    .out_dma_instr   (out_dma_instr),
    .out_math_instr  (out_math_instr),
    .out_cache_instr (out_cache_instr),
    .empty           (empty),
    .we              (we),
    .in_instr_type   (in_instr_type),
    .copy_count      (copy_count),
    .cache_addr      (cache_addr),
    .main_mem_addr   (main_mem_addr),
    .d_cache_addr    (d_cache_addr),
    .d_main_mem_addr (d_main_mem_addr),
    .in_arith_instr  (in_arith_instr),
    .in_ram_instr    (in_ram_instr),
    .in_ld_st_instr  (in_ld_st_instr),
    .needs_reset     (needs_reset)
    );

    // To create a clock:
    initial clk = 0;
    always #2 clk = ~clk;

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

    `UNIT_TEST("SIMPLE_TEST")
        reset = 1;
        @(posedge clk); #1
        reset = 0;
        re = 1;
        @(posedge clk); #1
        `ASSERT((dut.varray_read_pos === 1));
        re = 0;
        `ASSERT((out_math_instr === 0));
        we = 1;
        in_instr_type = INSTR_TYPE_ARITHMETIC;
        copy_count = 16;
        in_arith_instr = 16'h8600; // gt0 (first 6 bits will get chopped)
        `ASSERT((dut.next_free_spot_in_varray[INSTR_TYPE_ARITHMETIC] === 0));
        @(posedge clk);#1
        `ASSERT((dut.next_free_spot_in_varray[INSTR_TYPE_ARITHMETIC] === 17));
        @(posedge clk); #1
        re = 1;
        we = 0;
        repeat(32) begin
            @(posedge clk); #1
            `ASSERT((out_math_instr === 10'h200));
        end
        @(posedge clk); #1
        `ASSERT((out_math_instr === 0));
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
