/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

`include "../../bigvendor/uart/rtl/uart_rx.v"
`include "../../bigvendor/uart/rtl/uart_tx.v"
`include "../types.sv"
`include "dma_uart.sv"


`timescale 1 ns / 100 ps

module dma_uart_testbench();

    `SVUT_SETUP

    logic clk     ;
    logic reset ;
    logic [17:0]      dma_dat_w;
    logic [6:0]       host_mem_addr;
    logic valid_instr;
    logic we;
    logic         busy;
    logic        uart_rxd;
    logic        uart_txd;
    dma_stage_3_instr cache_write_port;

    dma_uart 
    dut 
    (
    .clk(clk),
    .reset(reset),
    .instr({dma_dat_w, valid_instr, we, host_mem_addr, 2'd2, 11'd0}),
    .busy(busy),
    .cache_write_port(cache_write_port),
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd)
    );

    initial clk = 0;
    always #2 clk = ~clk;

    // To dump data for visualization:
    // initial begin
    //     $dumpfile("dma_uart_testbench.vcd");
    //     $dumpvars(0, dma_uart_testbench);
    // end

    // Setup time format when printing with $realtime
    initial $timeformat(-9, 1, "ns", 8);

    task posedge_uart_and_assert_val_equal(input val);
        begin
            repeat(10416) begin
                @(posedge clk);
                //$display("%x", uart_txd);
                //$display("%d %d %d %d", dut.S, dut.i_uart_tx.uart_tx_busy, dut.i_uart_tx.uart_tx_en, dut.i_uart_tx.fsm_state);
            end
            #1 `ASSERT((uart_txd === val));
        end
    endtask
    task setup(msg="");
    begin
        /// setup() runs when a test begins
        reset = 1;
        @(posedge clk); #1
        reset = 0;
        @(posedge clk); #1
        `ASSERT((busy === 0));
        `ASSERT((uart_txd === 1));
    end
    endtask

    task teardown(msg="");
    begin
        /// teardown() runs when a test ends
    end
    endtask

    `TEST_SUITE("SUITE_NAME")

    `UNIT_TEST("BASIC_TEST")
        @(posedge clk); #1
        `ASSERT((busy === 0));
        
        dma_dat_w = 18'b110101110100010101;
        host_mem_addr = 7'b0011001;
        we = 1'b1;
        valid_instr = 1'b1;
        @(posedge clk); #1
        valid_instr = 1'b0;
        `ASSERT((busy === 1));

        //
        // Write command
        //
        `ASSERT((uart_txd === 1)); // start high
        posedge_uart_and_assert_val_equal(0); // go low
        // actual data now (remmeber uart does sends out starting with LSB ending with MSB)   
        for(integer i = 0; i < 7; i = i + 1) begin
            posedge_uart_and_assert_val_equal(host_mem_addr[i]);
        end
        posedge_uart_and_assert_val_equal(1); // first bit (MSB) is saying the command is write enable


        //
        // Most significant bits of fp16 casted tf32
        //
        posedge_uart_and_assert_val_equal(1); // start high
        posedge_uart_and_assert_val_equal(0); // go low
        for(integer i = 10; i < 18; i = i + 1) begin
            posedge_uart_and_assert_val_equal(dma_dat_w[i]);
        end

        //
        // Least significant bits of cherry float casted tf32
        //
        posedge_uart_and_assert_val_equal(1); // start high
        posedge_uart_and_assert_val_equal(0); // go low
        for(integer i = 2; i < 10; i = i + 1) begin // note 2 bits of the mantissa are chopped off to cast from cherry float to fp16
            posedge_uart_and_assert_val_equal(dma_dat_w[i]);
        end

        `ASSERT((busy === 1));
        @(posedge clk); #1
        `ASSERT((busy === 1));
        wait(!busy);
        `ASSERT((busy === 0));

    `UNIT_TEST_END

    // `UNIT_TEST("BASIC_READ")
    //     `ASSERT((busy === 0));
    //     dma_dat_w = 0;
    //     host_mem_addr = 0;
    //     we = 1'b0;
    //     @(posedge clk); #1
    //     `ASSERT((busy === 0));
    //     `ASSERT((cache_write_port.dat === (18'd1337 << 2)));
    //     `ASSERT((cache_write_port.raw_instr_data.valid === 1'b1));
    //     `ASSERT((cache_write_port.raw_instr_data.mem_we === 1'b0));
    //     `ASSERT((cache_write_port.raw_instr_data.cache_slot === 2'd2));

    // `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
