/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "types.sv"
`include "loopmux.sv"
`include "control_unit.sv"

`timescale 1 ns / 100 ps

module control_unit_unit_test();

    `SVUT_SETUP
    bit [0:15] icache [15:0];
    always @(posedge clk) begin
        #1 raw_instruction = icache[pc];
    end
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
    logic  [0:13] queue_arith_instr;
    logic  [0:8]  queue_ram_instr;
    logic [0:9]  queue_ld_st_instr;
    logic program_complete;
    control_unit 
    dut 
    (
    clk,
    reset,
    program_complete,
    raw_instruction,
    pc,
    prog_apu_formula,
    prog_loop_ro_data,
    cache_addr, main_mem_addr, d_cache_addr, d_main_mem_addr,
    queue_we,
    queue_instr_type,
    queue_arith_instr,
    queue_ram_instr,
    queue_ld_st_instr
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
    task automatic posedge_clk_until_queue_we_is_on_with_max_iter(int max_iterations);
        int done = 0; // break statement not supported :(
        for(int i = 0; i < max_iterations; i++) begin
            if (!done) @(posedge clk);
            if (queue_we === 1'b1) done = 1;
        end
    endtask
    task automatic posedge_clk_until_program_complete_and_assert_no_more_queue_write_with_max_iter(int max_iterations);
        int done = 0; // break statement not supported :(
        for(int i = 0; i < max_iterations; i++) begin
            int old = dut.S;
            if (!done) @(posedge clk);
            if (program_complete === 1'b1) done = 1;
            `ASSERT((queue_we === 1'b0));
        end
    endtask
    
    
    `TEST_SUITE("SUITE_NAME")

    `UNIT_TEST("RELU_SLOW_PROG")
    icache[6] = 16'hd000;  // start_loop
    icache[7] = 16'h4080;  // cisa_mem_read
    icache[8] = 16'h0000;  // cisa_load
    icache[9] = 16'h8000;  // cisa_relu
    icache[10] = 16'h0300; // cisa_store
    icache[11] = 16'h6120; // cisa_mem_write
    icache[12] = 16'hc000; // end_loop_or_jump
    `ASSERT((dut.S === dut.IDLE));
    @(posedge clk); #1
    `ASSERT((dut.S === dut.PREPARE_PROGRAM_0));
    prog_apu_formula = 648'h000040000000000000000000000000000000000000001000000000000000000000000000000000100000040000000000000000000000000000000008000000000000000000000000000000000000000000;
    prog_loop_ro_data = 192'h004006000000000000000000000000000000000000000000;
    @(posedge clk); #1
    `ASSERT((dut.S === dut.PREPARE_PROGRAM_1));
    prog_apu_formula = 648'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    @(posedge clk); #1
    `ASSERT((dut.S === dut.DECODE));
    `ASSERT((pc == 6));
    for(int k = 0; k < 256; k++) begin
        posedge_clk_until_queue_we_is_on_with_max_iter(10);
        `ASSERT((queue_we === 1'b1));
        `ASSERT((queue_instr_type === INSTR_TYPE_RAM));
        `ASSERT((queue_ram_instr === icache[7][2:10]));
        @(posedge clk);
        `ASSERT((queue_we === 1'b0));
        posedge_clk_until_queue_we_is_on_with_max_iter(10);
        `ASSERT((queue_we === 1'b1));
        `ASSERT((queue_instr_type === INSTR_TYPE_LOAD_STORE));
        `ASSERT((queue_ld_st_instr === icache[8][2:11]));
        posedge_clk_until_queue_we_is_on_with_max_iter(10);
        `ASSERT((queue_we === 1'b1));
        `ASSERT((queue_instr_type === INSTR_TYPE_ARITHMETIC));
        `ASSERT((queue_arith_instr === icache[9][2:15]));
        posedge_clk_until_queue_we_is_on_with_max_iter(10);
        `ASSERT((queue_we === 1'b1));
        `ASSERT((queue_instr_type === INSTR_TYPE_LOAD_STORE));
        `ASSERT((queue_ld_st_instr === icache[10][2:11]));
        posedge_clk_until_queue_we_is_on_with_max_iter(10);
        `ASSERT((queue_we === 1'b1));
        `ASSERT((queue_instr_type === INSTR_TYPE_RAM));
        `ASSERT((queue_ram_instr === icache[11][2:10]));
        @(posedge clk);
        `ASSERT((queue_we === 1'b0));
    end
    // loop is over now. program should be done! Stop pushing things to instruction queue
    posedge_clk_until_program_complete_and_assert_no_more_queue_write_with_max_iter(10);
    `ASSERT((program_complete === 1'b1));

    `UNIT_TEST_END

    `UNIT_TEST("TINY_PROG")
        // simple program
        // start_loop, cisa_mem_read, end_loop_or_jump
        // cisa_start_loop(independent=False, loop_addr=0) // bits loop instr, non independent, start loop, loop location 0, fill
        icache[6] = 16'hD000; // bit_pack_loop_instruction(is_independent=False, is_start_loop=True, loop_address=0)
        // cisa_mem_read(cache_apu_addr=2, main_mem_apu_addr=4, cache_slot=0) // bits ram instr, non write, cache apu, main mem apu, cache_slot, fill
        icache[7] = 16'h4A00; // bit_pack_ram_instruction(is_write=False, cache_apu_address=2, main_memory_apu_address=4, cache_slot=0)
        // cisa_end_loop()
        icache[8] = 16'hC000; // bit_pack_loop_instruction(is_start_loop=False)

        
        `ASSERT((dut.S === dut.IDLE));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.PREPARE_PROGRAM_0));
        prog_apu_formula = 648'h000180000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000001000000000000000000000000000000000000000000000;
        prog_loop_ro_data = 192'h0000c2000000000000000000000000000000000000000000;
        @(posedge clk); #1
        `ASSERT((dut.S === dut.PREPARE_PROGRAM_1));
        prog_apu_formula = 648'h0000000000000000020000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
        @(posedge clk); #1
        `ASSERT((dut.S === dut.DECODE));
        `ASSERT((pc == 6));

        @(posedge clk); #1
        `ASSERT((dut.S === dut.START_NEW_LOOP));
        
        `ASSERT((dut.instruction_type === INSTR_TYPE_LOOP));
        
        
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_APU));
        
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_PC));
        `ASSERT((pc === 6));
        @(posedge clk); #1
        `ASSERT((pc === 7));
        `ASSERT((dut.S === dut.DECODE));
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
        `ASSERT((dut.S === dut.DECODE));
        `ASSERT((dut.loop_stack_value[0] === 0));

        @(posedge clk); #1
        `ASSERT((dut.S === dut.INCREMENT_LOOP));
        `ASSERT((dut.loop_stack_value[0] === 0));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_APU));
        `ASSERT((dut.loop_stack_value[0] === 1));
        `ASSERT((pc === 8));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_PC));
        `ASSERT((pc === 8));

        // Jump and start second iteration here

        @(posedge clk); #1
        `ASSERT((pc === 7));
        `ASSERT((dut.S === dut.DECODE));

        @(posedge clk); #1
        `ASSERT((dut.instruction_type === INSTR_TYPE_RAM));
        `ASSERT((dut.S === dut.INSERT_TO_QUEUE));
        `ASSERT((queue_we === 0));

        @(posedge clk); #1
        `ASSERT((main_mem_addr === 3));
        `ASSERT((cache_addr === 2));
        `ASSERT((queue_we === 1));
        `ASSERT((queue_instr_type === INSTR_TYPE_RAM));
        `ASSERT((dut.S === dut.UPDATE_PC));
        `ASSERT((pc === 7));
        @(posedge clk); #1
        `ASSERT((queue_we === 0));
        `ASSERT((pc === 8));
        `ASSERT((dut.S === dut.DECODE));
        `ASSERT((dut.loop_stack_value[0] === 1));

        @(posedge clk); #1
        `ASSERT((dut.S === dut.INCREMENT_LOOP));
        `ASSERT((dut.loop_stack_value[0] === 1));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_APU));
        `ASSERT((dut.loop_stack_value[0] === 2));
        `ASSERT((pc === 8));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_PC));
        `ASSERT((pc === 8));

        // Jump and start third iteration here

        @(posedge clk); #1
        `ASSERT((pc === 7));
        `ASSERT((dut.S === dut.DECODE));

        @(posedge clk); #1
        `ASSERT((dut.instruction_type === INSTR_TYPE_RAM));
        `ASSERT((dut.S === dut.INSERT_TO_QUEUE));
        `ASSERT((queue_we === 0));

        @(posedge clk); #1

        `ASSERT((main_mem_addr === 3));
        `ASSERT((cache_addr === 4));
        `ASSERT((queue_we === 1));
        `ASSERT((queue_instr_type === INSTR_TYPE_RAM));
        `ASSERT((dut.S === dut.UPDATE_PC));
        `ASSERT((pc === 7));
        @(posedge clk); #1
        `ASSERT((queue_we === 0));
        `ASSERT((pc === 8));
        `ASSERT((dut.S === dut.DECODE));
        `ASSERT((dut.loop_stack_value[0] === 2));

        @(posedge clk); #1
        `ASSERT((dut.S === dut.INCREMENT_LOOP));
        `ASSERT((dut.loop_stack_value[0] === 2));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_APU));
        `ASSERT((dut.loop_stack_value[0] === 3));
        `ASSERT((pc === 8));
        @(posedge clk); #1
        `ASSERT((dut.S === dut.UPDATE_PC));
        `ASSERT((pc === 8));
        @(posedge clk); #1
        `ASSERT((pc === 9));

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
