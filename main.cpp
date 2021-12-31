#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "CherrySim.h"
#include <fstream>
#include "uartsim.h"
#include <chrono>
#include <ctime> 
#include <unistd.h>
// #include "Valu___024unit.h"

#define MAX_CYCLE_CNT 10000000
vluint64_t cycle_cnt = 0;

double sc_time_stamp() { return 0; } // lol

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
    dut->sw_0 = 0;
    printf("Cherry Zero Simulator Initialized and Ready\n");
}

void log_instruction_queue_if_needed(CherrySim *dut, std::ofstream &wf, std::ofstream &rf) {
    if (dut->top__DOT__queue_we) {
        switch (dut->top__DOT__queue_instr_type)
        {
        case 0:
            wf << "cisa_loadstore      ";break;
        case 1: wf << "cisa_mem_readwrite  ";break;
        case 2: wf << "cisa_math           ";break;
        }

        wf << dut->top__DOT__queue_copy_count;
        wf << " insert pos " << dut->top__DOT__instruction_queue__DOT__insert_varray_pos;
        // wf << " dma instr pos when done " << dut->top__DOT__instruction_queue__DOT__varray_pos_when_done[];
        switch (dut->top__DOT__queue_instr_type)
        {
        case 0:
            wf << " cache addr " << dut->top__DOT__cache_addr;
            break;
        case 1:
            wf << " cache addr " << dut->top__DOT__cache_addr;
            wf << " main mem addr " << (dut->top__DOT__main_mem_addr & 0x7F);
            break;
        }
        wf << "\n";
    }
    static bool prev_re = false;
    
    if (prev_re) {
        
        bool dma_valid = dut->top__DOT____Vcellout__instruction_queue__out_dma_instr >> 21;
        bool cache_valid = dut->top__DOT__cache_instr_stage_1 >> 20;
        bool math_valid = dut->top__DOT__m_instr >> 13;
        if (dma_valid || cache_valid || math_valid) {
            rf << "dma val " << dma_valid;
            rf << " cache val " << cache_valid << "cache reg " << (dut->top__DOT__cache_instr_stage_1 & 0x0000003);
            rf << " math val " << math_valid;
            rf << "\n";
        }
        
    } else {
        rf << "skipped read\n";
    }
    prev_re = dut->top__DOT__q_re;
}

void tick(CherrySim *const dut) {
    dut->clk = 1;
    dut->eval();
    dut->clk = 0;
    dut->eval();
}
int main(int argc, char** argv, char** env) {
    std::ofstream wf("iq_writes.csv", std::ios_base::app);
    std::ofstream rf("iq_reads.csv", std::ios_base::app);

    printf("Starting the Cherry Zero Simulator\n");
    CherrySim *dut = new CherrySim;
    UARTSIM *uart = new UARTSIM(1338);
    const int cyclesPerBit = 2604; // 50e6 hz / 19200 baud
    uart->setup(cyclesPerBit);
    // printf("%d", uart->m_setup);
    reset(dut);
    int count = 0;
    while(true) {
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
        tick(dut);
        cycle_cnt++;
        
        //log_instruction_queue_if_needed(dut, wf, rf);
        assert(!dut->error);
    }
}