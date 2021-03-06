#!/usr/bin/env bash

# From SVUT examples
# install SVUT
export SVUT=$HOME/.svut
git clone https://github.com/dpretet/svut.git $SVUT
export PATH=$SVUT:$PATH

# Get script's location
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -ex
# pipe fails if first command fails. Else is always successful
set -o pipefail

# Program Cache Test Suite
cd core/ControlUnit
"svutRun" -test "ro_data_mem_unit_test.sv" -define "MYDEF1=5;MYDEF2" | tee log
rm icarus.out
cd ../../
ret=$?

if [[ $ret != 0 ]]; then
    echo "Execution failed but should not..."
    exit 1
else
    echo "OK testsuite execution completed successfully ^^"
fi

# Regfile Test Suite
cd core/Memory
"svutRun" -test "regfile_unit_test.sv" -define "MYDEF1=5;MYDEF2" | tee log
rm icarus.out log
cd ../../
ret=$?

if [[ $ret != 0 ]]; then
    echo "Execution failed but should not..."
    exit 1
else
    echo "OK testsuite execution completed successfully ^^"
fi

# Dcache Test Suite
# cd core/Memory
# "svutRun" -test "dcache_unit_test.sv" -define "MYDEF1=5;MYDEF2" | tee log
# rm icarus.out log
# cd ../../
# ret=$?

# if [[ $ret != 0 ]]; then
#     echo "Execution failed but should not..."
#     exit 1
# else
#     echo "OK testsuite execution completed successfully ^^"
# fi

# Low performance DMA UART Test Suite
cd core/Dma
"svutRun" -test "dma_uart_unit_test.sv" -define "MYDEF1=5;MYDEF2" | tee log
rm icarus.out log
cd ../../
ret=$?

if [[ $ret != 0 ]]; then
    echo "Execution failed but should not..."
    exit 1
else
    echo "OK testsuite execution completed successfully ^^"
fi

# Float multiply test
cd core/Processing/FloatingPoint
./test.sh
cd ../../../
if [[ $ret != 0 ]]; then
    echo "Execution failed but should not..."
    exit 1
else
    echo "OK testsuite execution completed successfully ^^"
fi


# Float Group Sum Test Suite
cd core/Processing/FloatingPoint
"svutRun" -test "GroupSum_unit_test.sv" -define "MYDEF1=5;MYDEF2" | tee log
rm icarus.out log
cd ../../
ret=$?

if [[ $ret != 0 ]]; then
    echo "Execution failed but should not..."
    exit 1
else
    echo "OK testsuite execution completed successfully ^^"
fi


# Add more testsuites here

echo "Regression finished successfully. SVUT sounds alive ^^"
exit 0