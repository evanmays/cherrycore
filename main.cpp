#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "CherrySim.h"
#include "uartsim.h"
#include <chrono>
#include <ctime> 
#include <unistd.h>
// #include "Valu___024unit.h"

#define MAX_CYCLE_CNT 10000000
vluint64_t cycle_cnt = 0;

void reset(CherrySim *dut) {
    dut->sw_0 = 1;
    dut->clk = 0;
    dut->uart_rxd = 1;
    dut->eval();
    for (int i = 0; i < 10; i ++) {
        dut->clk = 1;
        dut->eval();
        dut->clk = 0;
        dut->eval();
    }
    sleep(5);
    dut->sw_0 = 0;
}
int main(int argc, char** argv, char** env) {
    // printf("Starting the Cherry Zero Simulator\n");
    CherrySim *dut = new CherrySim;
    UARTSIM *uart = new UARTSIM(1337);
    uart->setup(10416); // 50e6 hz / 4800 baud
    // printf("%d", uart->m_setup);
    reset(dut);
    auto start = std::chrono::system_clock::now();
    int count = 0;
    for(int i = 0; i < 50000000; i++) {// while (true) {
        if (count == 0 && dut->top__DOT____Vcellout__instruction_queue__out_dma_instr >> 22 > 0) {
            count++;
        } else if (count > 0 && count < 16) {
            printf("dma we %d\n", dut->top__DOT____Vcellout__instruction_queue__out_dma_instr >> 22);
            count++;
        }
        
        dut->uart_rxd = (*uart)(dut->uart_txd);
        // one solution is to fork uartsim to also return the byte from uart. then we can pass this to python some how
        // another way is to let this be an independent process that allows access over network
        // then tinygrad can connect to the simulator over network as opposed to physical device on pcie or ethernet
        // you want two processes anyway. This allows you to run simulators on big computer
        // but now python cant read internals. the sim process can dump this info though and be told to pause whenever python gets something it doesn't expect
        // we can even wrap into a single network endpoint. This wrapper communicates with the sim proces and fowards uart process http
        // then you also have the process running on host computer that manages connection to device. this process is a dma process. it shares memory space with tinygrad. I guess it can be in tinygrad but it needs to be non blocking. so a process fork probably
        // posedge
        dut->clk = 1;
        dut->eval();
        dut->clk = 0;
        dut->eval();
        cycle_cnt++;
    }

    auto end = std::chrono::system_clock::now();

    std::chrono::duration<double> elapsed_seconds = end-start;
    printf("Elapsed %lf s\n", elapsed_seconds);

    delete dut;
    exit(EXIT_SUCCESS);
}