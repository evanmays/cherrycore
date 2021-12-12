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
    logic [10:0]                            cache_addr, d_cache_addr;
    logic [6:0]                             main_mem_addr, d_main_mem_addr;
    logic [0:8]                             in_arith_instr;
    logic [0:2]                             in_ram_instr;
    logic [0:6]                             in_ld_st_instr;
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
        in_arith_instr = 9'b000110000; // gt0 (first 7 bits will get chopped)
        `ASSERT((dut.next_free_spot_in_varray[INSTR_TYPE_ARITHMETIC] === 0));
        @(posedge clk);#1
        `ASSERT((dut.next_free_spot_in_varray[INSTR_TYPE_ARITHMETIC] === 17));
        @(posedge clk); #1
        re = 1;
        we = 0;
        repeat(32) begin
            @(posedge clk); #1
            $display("%b", out_math_instr);
            `ASSERT((out_math_instr === 10'b1000110000));
        end

        @(posedge clk); #1
        `ASSERT((out_math_instr === 0));
    `UNIT_TEST_END


    `UNIT_TEST("REAL_GT0_PROG_TEST")
        // cisa_mem_read, cisa_load, cisa_gt0, cisa_store, cisa_mem_write

        reset = 1;
        @(posedge clk); #1
        reset = 0;

        we = 1;
        re = 0;
        copy_count = 16;

        in_instr_type = INSTR_TYPE_RAM;
        in_ram_instr = {1'b0, INPUT_CACHE_SLOT}; // RAM to slot 0
        cache_addr = 0;
        d_cache_addr = 1;
        main_mem_addr = 32;
        d_main_mem_addr = 4;
        @(posedge clk);#1

        in_instr_type = INSTR_TYPE_LOAD_STORE;
        in_ld_st_instr = {1'b1, INPUT_CACHE_SLOT, INPUT_REG, 1'b0, 1'b0};
        cache_addr = 0;
        d_cache_addr = 1;
        @(posedge clk);#1

        in_instr_type = INSTR_TYPE_ARITHMETIC;
        in_arith_instr = 9'b000110000;
        @(posedge clk);#1

        in_instr_type = INSTR_TYPE_LOAD_STORE;
        in_ld_st_instr = {1'b0, OUTPUT_CACHE_SLOT, OUTPUT_REG, 1'b0, 1'b0};
        cache_addr = 0;
        d_cache_addr = 1;
        @(posedge clk);#1

        in_instr_type = INSTR_TYPE_RAM;
        in_ram_instr = {1'b1, OUTPUT_CACHE_SLOT}; // slot 1 to RAM
        cache_addr = 0;
        d_cache_addr = 1;
        main_mem_addr = 64;
        d_main_mem_addr = 1;
        @(posedge clk);#1
        re = 1;
        we = 0;
        // read 0
        @(posedge clk); #1
        `ASSERT((out_dma_instr.valid === 1'b1));
        `ASSERT((out_dma_instr.mem_we === 1'b0));
        `ASSERT((out_dma_instr.main_mem_addr === 7'd32));
        `ASSERT((out_dma_instr.cache_slot === INPUT_CACHE_SLOT));
        `ASSERT((out_dma_instr.cache_addr === 0));
        `ASSERT((out_cache_instr.valid === 1'b0));
        `ASSERT((out_math_instr.valid === 1'b0));

        // read 1
        @(posedge clk); #1
        `ASSERT((out_dma_instr.valid === 1'b1));
        `ASSERT((out_dma_instr.mem_we === 1'b0));
        `ASSERT((out_dma_instr.main_mem_addr === 7'd36));
        `ASSERT((out_dma_instr.cache_slot === INPUT_CACHE_SLOT));
        `ASSERT((out_dma_instr.cache_addr === 1));
        `ASSERT((out_cache_instr.valid === 1'b0));
        `ASSERT((out_math_instr.valid === 1'b0));

        // read 2
        @(posedge clk); #1
        `ASSERT((out_dma_instr.valid === 1'b1));
        `ASSERT((out_dma_instr.mem_we === 1'b0));
        `ASSERT((out_dma_instr.main_mem_addr === 7'd40));
        `ASSERT((out_dma_instr.cache_slot === INPUT_CACHE_SLOT));
        `ASSERT((out_dma_instr.cache_addr === 2));
        `ASSERT((out_cache_instr.valid === 1'b1));
        `ASSERT((out_cache_instr.is_load === 1'b1));
        `ASSERT((out_cache_instr.cache_slot === INPUT_CACHE_SLOT));
        `ASSERT((out_cache_instr.cache_addr === 11'd0));
        `ASSERT((out_cache_instr.regfile_reg === INPUT_REG));
        `ASSERT((out_math_instr.valid === 1'b0));


        // @(posedge clk); #1
        // `ASSERT((out_math_instr === 0));
    `UNIT_TEST_END

    `TEST_SUITE_END

    parameter INPUT_CACHE_SLOT = 2'd0;
        parameter OUTPUT_CACHE_SLOT = 2'd1;
        parameter INPUT_REG = 2'd0;
        parameter OUTPUT_REG = 2'd2;

endmodule
