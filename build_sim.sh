set -e
UART=bigvendor/uart
# 
verilator -Wno-lint --exe main.cpp uartsim.cpp --prefix CherrySim --top-module top --cc core/types.sv core/Processing/pipeline.sv core/Memory/regfile.sv core/Memory/dcache.sv $UART/rtl/uart_tx.v $UART/rtl/uart_rx.v core/Dma/dma_uart.sv core/ControlUnit/types.sv core/FIFO/varray.sv core/FIFO/iq.sv core/ControlUnit/fake_control_unit.sv core/top.sv
make -C obj_dir -f CherrySim.mk CherrySim
./obj_dir/CherrySim
# xxd out.txt
