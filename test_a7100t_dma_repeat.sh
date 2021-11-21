# later, add optional program
set -ex
mkdir -p out
cd out
UART=../bigvendor/uart
# synthesize with iverilog just since it has better error checking than yosys. We won't actually use iverilog's output
iverilog -g2012 ../core/dma/top_dma_uart_dumb_test.sv ../core/dma/dma_uart.sv $UART/rtl/uart*.v
/usr/local/bin/yosys  -p "synth_xilinx -flatten -nowidelut -family xc7 -top top; write_json attosoc.json" ../core/dma/top_dma_uart_dumb_test.sv ../core/dma/dma_uart.sv $UART/rtl/uart*.v
$HOME/cherry/nextpnr-xilinx/nextpnr-xilinx --freq 50 --chipdb $HOME/cherry/nextpnr-xilinx/xilinx/xc7a100t.bin --xdc $UART/constraints/defaults.xdc --json attosoc.json --write attosoc_routed.json --fasm attosoc.fasm

XRAY_UTILS_DIR=$HOME/cherry/prjxray/utils
XRAY_TOOLS_DIR=$HOME/cherry/prjxray/build/tools
XRAY_DATABASE_DIR=$HOME/cherry/prjxray/database

# prereq, cd ~. clone prjxray and do the git submodule init thing from their readme. then do ./download-latest-db.sh
"${XRAY_UTILS_DIR}/fasm2frames.py" --db-root "${XRAY_DATABASE_DIR}/artix7" --part xc7a100tcsg324-1 attosoc.fasm > attosoc.frames
"${XRAY_TOOLS_DIR}/xc7frames2bit" --part_file "${XRAY_DATABASE_DIR}/artix7/xc7a100tcsg324-1/part.yaml" --part_name xc7a100tcsg324-1 --frm_file attosoc.frames --output_file attosoc.bit

cd ../
openocd -d -f real/digilent_arty.cfg

read -n 1 -s -r -p "Flip the reset switch to up position then down position on the fpga then press enter to continue." throwawayvar
python3 repeat_test.py