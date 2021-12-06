iverilog -g2012 -o hardware_mul Mul_Run.sv
gcc -msse -mfpmath=sse -ffast-math -O3 testsuite.c -o test
./test
rm test hardware_mul