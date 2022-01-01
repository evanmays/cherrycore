set -e
UART=bigvendor/uart
# -Wno-LITENDIAN -Wno-CASEINCOMPLETE -Wno-PINMISSING
verilator -Wno-lint -CFLAGS -DVL_TIME_CONTEXT --exe main.cpp uartsim.cpp --prefix CherrySim --top-module top --cc core/FIFO/smplfifo.v core/types.sv core/Memory/fake_pcache.sv core/ControlUnit/loopmux.sv core/ControlUnit/control_unit.sv core/Processing/UnopALU.sv core/Processing/pipeline.sv core/Memory/regfile.sv core/Memory/dcache.sv core/FIFO/prefetch_initiate_superscalar_fifo.sv $UART/rtl/uart_tx.v $UART/rtl/uart_rx.v core/Dma/PacketReceiver.sv core/Dma/PacketSender.sv core/FIFO/varray.sv core/FIFO/iq.sv core/ControlUnit/pcache.sv core/top.sv
make -C obj_dir -f CherrySim.mk CherrySim
./obj_dir/CherrySim
# xxd out.txt
