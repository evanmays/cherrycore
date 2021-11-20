/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

`include "../../bigvendor/uart/rtl/uart_tx.v"
`include "dma_uart.sv"

`timescale 1 ns / 100 ps

module dma_uart_testbench();

    `SVUT_SETUP

    logic clk     ;
    logic reset ;
    logic [17:0]      dma_dat_w;
    logic [6:0]       dma_dat_addr;
    logic we;
    logic         busy;
    logic        uart_rxd;
    logic        uart_txd;

    dma_uart 
    dut 
    (
    clk,
    reset,
    dma_dat_w,
    dma_dat_addr,
    we,
    busy,
    uart_rxd,
    uart_txd
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

    task setup(msg="");
    begin
        /// setup() runs when a test begins
        reset = 1;
        @(posedge clk); #1
        reset = 0;
        @(posedge clk); #1
        `ASSERT((busy == 0));
        `ASSERT((uart_txd == 1));
    end
    endtask

    task teardown(msg="");
    begin
        /// teardown() runs when a test ends
    end
    endtask

    `TEST_SUITE("SUITE_NAME")

    `UNIT_TEST("TEST_NAME")
        @(posedge clk); #1
        `ASSERT((busy == 0));
        $display("%x", uart_txd);
        
        dma_dat_w = 18'd20;
        dma_dat_addr = 7'd9;
        we = 1'b1;
        @(posedge clk); #1
        `ASSERT((busy == 1));
        // sample uart_txd at baud rate and assert it's value

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
