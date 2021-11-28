/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "types.sv"
`include "loopmux.sv"
`include "control_unit.sv"

`timescale 1 ns / 100 ps

module control_unit_unit_test();

    `SVUT_SETUP

    parameter LOG_LOOP_CNT = 3;
    logic clk;
    logic reset;
    bit  [0:15]  raw_instruction;
    logic  [15:0]  pc;
    logic [4*9*18-1:0] prog_apu_formula;
    logic [0:24*8-1]   prog_loop_ro_data;
    logic  [17:0] cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr;
    logic [18*8-1:0] linear_formula;;
    logic [LOG_LOOP_CNT-1:0] loop_var;

    control_unit 
    dut 
    (
    clk,
    reset,
    raw_instruction,
    pc,
    prog_apu_formula,
    prog_loop_ro_data,
    cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr
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
        `ASSERT((dut.S === dut.IDLE));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.PREPARE_PROGRAM_0));

        prog_apu_formula = 0;
        prog_loop_ro_data = 0;
        @(posedge clk); #1
        `ASSERT((dut.S === dut.PREPARE_PROGRAM_1));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.DECODE));

        // cisa_start_loop(independent=False, loop_addr=0) // bits loop instr, non independent, start loop, loop location 0, fill
        raw_instruction = {2'd3, 1'b0, 1'b1, 3'b0, 9'd0}; // DPI call python cisa_ function with assembler mode enabled.
        @(posedge clk); #1
        `ASSERT((dut.S === dut.START_NEW_LOOP));
        
        $display("%x %x", dut.instruction_type, dut.raw_instruction[0:1]);
        `ASSERT((dut.instruction_type === INSTR_TYPE_LOOP));
        
        
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_APU));
        
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_PC));
        `ASSERT((pc === 6));
        @(posedge clk); #1
        `ASSERT((pc === 7));
        `ASSERT((dut.S === dut.DECODE));
        
        // cisa_mem_read(cache_apu_addr=2, main_mem_apu_addr=4) // bits ram instr, non write, cache apu, main mem apu, fill
        raw_instruction = {2'd1, 1'b0, 3'd2, 3'd4, 7'd0}; // DPI call python cisa_ function with assembler mode enabled.
        @(posedge clk); #1
        `ASSERT((dut.instruction_type === INSTR_TYPE_RAM));
        

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
