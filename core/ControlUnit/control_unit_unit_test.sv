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
    logic         queue_we;
    logic  [1:0]  queue_instr_type;

    control_unit 
    dut 
    (
    clk,
    reset,
    raw_instruction,
    pc,
    prog_apu_formula,
    prog_loop_ro_data,
    cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr,
    queue_we,
    queue_instr_type
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

    `UNIT_TEST("TEST_NAME")
        `ASSERT((dut.S === dut.IDLE));
        @(posedge clk); #1
        $display("%d %d", dut.apu_address_registers[4], dut.loop_cur_depth);
        `ASSERT((dut.S === dut.PREPARE_PROGRAM_0));
        prog_apu_formula = 648'h000180000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000001000000000000000000000000000000000000000000000;
        prog_loop_ro_data = 192'h000103000000000000000000000000000000000000000000;
        @(posedge clk); #1
        $display("%d %d", dut.apu_address_registers[4], dut.loop_cur_depth);
        `ASSERT((dut.S === dut.PREPARE_PROGRAM_1));
        prog_apu_formula = 648'h0000000000000000020000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
        @(posedge clk); #1
        $display("%d %d", dut.apu_address_registers[4], dut.loop_cur_depth);
        `ASSERT((dut.S === dut.DECODE));

        // cisa_start_loop(independent=False, loop_addr=0) // bits loop instr, non independent, start loop, loop location 0, fill
        raw_instruction = {2'd3, 1'b0, 1'b1, 3'b0, 9'd0}; // Preprocessor script so we can put python cisa_ function here with assembler mode enabled.
        @(posedge clk); #1
        `ASSERT((dut.S === dut.START_NEW_LOOP));
        
        $display("%d %d", dut.apu_address_registers[4], dut.loop_cur_depth);
        `ASSERT((dut.instruction_type === INSTR_TYPE_LOOP));
        
        
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_APU));
        $display("%d %d", dut.apu_address_registers[4], dut.loop_cur_depth);
        
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_PC));
        $display("%d %d", dut.apu_address_registers[4], dut.loop_cur_depth);
        `ASSERT((pc === 6));
        @(posedge clk); #1
        `ASSERT((pc === 7));
        `ASSERT((dut.S === dut.DECODE));
        
        // cisa_mem_read(cache_apu_addr=2, main_mem_apu_addr=4, cache_slot=0) // bits ram instr, non write, cache apu, main mem apu, cache_slot, fill
        raw_instruction = 16'h4A00; // bit_pack_ram_instruction(is_write=False, cache_apu_address=2, main_memory_apu_address=4, cache_slot=0)
        
        @(posedge clk); #1
        `ASSERT((dut.instruction_type === INSTR_TYPE_RAM));
        `ASSERT((dut.S === dut.INSERT_TO_QUEUE));
        `ASSERT((queue_we === 0));

        @(posedge clk); #1
        `ASSERT((main_mem_addr === 3));
        `ASSERT((cache_addr === 0));
        `ASSERT((queue_we === 1));
        `ASSERT((queue_instr_type === INSTR_TYPE_RAM));
        `ASSERT((dut.S === dut.UPDATE_PC));
        `ASSERT((pc === 7));
        @(posedge clk); #1
        `ASSERT((queue_we === 0));
        `ASSERT((pc === 8));
        

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
