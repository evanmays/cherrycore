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

    task posedge_uart_and_assert_val_equal(input val);
        begin
            repeat(5208) begin
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

    `UNIT_TEST("TEST_NAME")
        @(posedge clk); #1
        `ASSERT((busy === 0));
        
        dma_dat_w = 18'b010101010101010101;
        dma_dat_addr = 7'b0011001;
        we = 1'b1;
        @(posedge clk); #1
        we = 1'b0;
        `ASSERT((busy === 1));

        `ASSERT((uart_txd === 1)); // start high
        posedge_uart_and_assert_val_equal(0); // go low
        // actual data now (remmeber uart does sends out starting with LSB ending with MSB)   
        for(integer i = 0; i < 7; i = i + 1) begin
            posedge_uart_and_assert_val_equal(dma_dat_addr[i]);
        end
        posedge_uart_and_assert_val_equal(1); // first bit (MSB) is saying the command is write enable
    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
