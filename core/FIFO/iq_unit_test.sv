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
    logic [LOG_SUPERSCALAR_WIDTH-1:0]       copy_count;
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

    ///    Available macros:"
    ///
    ///    - `MSG("message"):       Print a raw white message
    ///    - `INFO("message"):      Print a blue message with INFO: prefix
    ///    - `SUCCESS("message"):   Print a green message if SUCCESS: prefix
    ///    - `WARNING("message"):   Print an orange message with WARNING: prefix and increment warning counter
    ///    - `CRITICAL("message"):  Print a purple message with CRITICAL: prefix and increment critical counter 
    ///    - `ERROR("message"):     Print a red message with ERROR: prefix and increment error counter
    ///
    ///    - `FAIL_IF(aSignal):                 Increment error counter if evaluaton is true
    ///    - `FAIL_IF_NOT(aSignal):             Increment error coutner if evaluation is false
    ///    - `FAIL_IF_EQUAL(aSignal, 23):       Increment error counter if evaluation is equal
    ///    - `FAIL_IF_NOT_EQUAL(aSignal, 45):   Increment error counter if evaluation is not equal
    ///    - `ASSERT(aSignal):                  Increment error counter if evaluation is not true
    ///    - `ASSERT((aSignal == 0)):           Increment error counter if evaluation is not true
    ///
    ///    Available flag:
    ///
    ///    - `LAST_STATUS: tied to 1 is last macro did experience a failure, else tied to 0

    `UNIT_TEST("TEST_NAME")
        reset = 1;
        @(posedge clk); #1
        reset = 0;
        re = 1;
        @(posedge clk); #1
        re = 0;
        @(posedge clk); #1
        `ASSERT((out_math_instr === 0));
        we = 1;
        in_instr_type = INSTR_TYPE_ARITHMETIC;
        copy_count = 15; // really means 16
        in_arith_instr = 16'h8000; // relu
        @(posedge clk); #1
    

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
