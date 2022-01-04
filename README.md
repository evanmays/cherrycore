# Cherry Core

![Indicator of if Unit Tests workflow are passing](https://github.com/evanmays/cherrycore/actions/workflows/SVUT.yml/badge.svg)

A deep learning training core. First ~~on paper~~, then in verilator, then on FPGA, then on ASIC? The goal is to put the AS in ASIC... it's not even turing complete, but it trains neural nets faster and gets more done on a single chip.

Peformance should be on par with Google TPUs and AWS Trainiums at same process node sizes.

I've got the microarchitecture implemented. `./build_sim.sh` will build the verilog and start simulating the chip (accessible over tcp) and `python3 cherrysim.py` will run an example program as well as host the virtual device memory. In order to train MNIST need to add support for remaining instructions in the ISA. Some modules already done just need to integrate. Also need to convert `cherrysim.py` to a tinygrad extension.

# Intruction Set Architecture
Notes in `ISA in Cherry ISA.pdf` and `experiments/compiler/assembler.py`

Same cache bandwidth as a 3090 but due to the larger tile size we have 4x the arithmetic intensity (large matmul) on cache transfers. So, once data is on chip, the programs complete in a quarter the time.

Users can specify certain loops to have the loop bodies run in parallel. These parallel runs of the loops each have their own regfiles.

## Microarchitecture
There are 3 functional units all pipelined individually so they may in total complete 3 instructions per cycle. The first functional unit deals with cisa_mem_write and cisa_mem_read instructions. It's transfering data between device memory and device cache. The second functional unit supports cisa_load and cisa_store. It transfers data between device cache and the regfile. The third functional unit deals with all of our arithmetic insturctions. There are your cisa_matmul, cisa_relu, etc.

We feed the pipelines from an instruction queue. The instruction queueu is fed by the control unit. This unit is much simpler than most other superscalars. It utilizes the knowledge that ML programs are all loops. The programmer can replace a python range() function with cherry_range() and our superscalar unit will then treat each loop body as a thread allowing it to parallelize things. The control unit creates just 16 threads. This is enough to hide latency. Since the programs aren't turing complete, we can make a perfect branch predictor and prefetch all cisa_mem_read instructions.

There's also a program cache that can hold all the programs a forward and back pass would need (a few KB). And a program exection queue which allows the host device to schedule programs.

### Device Memory Access
For FPGA versions, use a reserved memory area in the host pc. Each memory access loads a tile, so I estimate over 100 megabit ethernet we can get 50% utilization. Larger FPGA will use pcie.

DMA (direct memory access) diagram here for Cherry on FPGA. [https://hackmd.io/@evanmays/r1G62pQsK](https://hackmd.io/@evanmays/r1G62pQsK)

For ASIC, only need 256GB/s per chip core. Probably cheapest/easiest to use GDDR.


### Cache Hierachy
**L3**

Our L3 cache stores data that was prefetched from device memory. Once you read from the L3 the data gets destroyed. This is because our L3 is a simple queue. It's smaller than L1 cache also.

**L2**

There is no L2 cache

**L1**

8 million elements (20MB) = 8000 tiles = 13-bit address path

Each address gives you access to a single (SZxSZ) tile of the tensor. The tile stores data across the final two dimensions. So, if you have an image tensor with shape (batch_size, channel_count, width, height) then a memory access lets you access a 32x32 tile for a specific batch and channel. Perhaps on cherry 3 an address range can be shared across cores and broadcast its reads to all cores. If just reshaping to swap the last two dimensions, no need to rearrange in mememory. If trying to rearrange more than that, we'll probably need some kind of transpose engine with first class reshape support. Maybe that looks like a coprocessor with a small strided memory.

Programmer manually cache. They are aided by our runtime telling them when a tensor is in cache already or not. They write two programs. One for if a tensor is in cache, another for if the tensor is not in cache. Nothing is stopping anyone from writing a good compiler that optimizes the memory accesses.

We want to support a load/store instruction into 32x32 matrix register (2432 bytes). The programmer can access 4 of these registers (input, weights, accumulate, output).

Convolution is the only program that really needs strided memory. We can have all of our cache load/store in tensor tiles. Then apply a first class convolution op on the tiles. Since we need to convolve at the edges between tiles, make it so we can load a tile plus padding from neighbooring tiles. We can guarantee no bank conflicts.

**Regfile**

Can store 16 threads worth of data. Each thread gets 4 registers. We name these: INPUT, WEIGHTS, OUTPUT, ACCUMULATOR. Each register holds a single SZxSZ tile. On a7100t SZ=4. So the entire regfile is 4x4x4x16x18/8 = 2304 bytes. On U250 SZ=16. On the asic, sz=32 so this is 32x32x4x16x18/8 = 147,456 bytes.

### Native arithmetic
For now, train a cherry float (18 bit floating point with 8 bit exponent.). Maybe do TF32 (19 bits) in future. Can we train AI in this precision? Everyone else is using mixed precision. If we have issues training here, allow user to turn on/off stocastic rounding. With stochastic rounding off, always round down, with stochastic rounding on, 20% (psuedo random) of the time you round up. This should be super cheap in hardware. True rounding is expensive, psudo-random bit flips are cheap.

First class support for matrix multiply (tensor core style). Maybe first class support for 3x3 and 5x5 convolutions over a 35x35 tile. We can just reuse the dot product FMAs from matmul. 3x3 is like 16 TFLOPs versus the matmul 64 TFLOPs. First class support for pooling? How does Trainium's pooling core work?

# Cherry 1 Stages

1. ~~Tiny Cherry 1, does 1 relu per cycle (50 MFLOPs) in simulator and on physical a7-100t. It's just scaffolding so rest of work can be done in parallel.~~
2. Small Cherry 1, does 6.4 GFLOPs with support for entire ISA in simulator and on physical a7-100t (finish remaining arithmetic isa support and use sv2v so we can yosys with all system verilog features)
3. Big Cherry 1, works on physical $7500 Alveo u250 fpga (or equivalent)
4. Cherry 2, same as big fpga but an asic and everything operates on 32x32 tiles not 16x16 tiles and there's real memory
5. Cherry 3, cherry 2 but with 4 cores instead of 1 and 4x the memory bandwidth.

Idea is similar to [this](https://github.com/geohot/tinygrad/tree/master/accel/cherry). But it's not a risc-v add-on. It's just an AI training chip. maybe i'll rename to root beer computer in honor of the rootbeer float.

# Contributors Getting Started

contributing is hard right now

### Prerequisites (MacOS & linux... sry Windows)
* icarus-verilog 
* yosys
* nextpnr-xilinx if you want to place and route to check for timing
* Verilator. Instructions here https://verilator.org/guide/latest/install.html
More build notes here https://github.com/geohot/tinygrad/blob/master/accel/cherry/build.sh
```sh
brew install icarus-verilog # Yes, even on linux
# add yosys
# nextpnr-xilinx might have more steps for mac i think
cd ~/cherry
git clone https://github.com/gatecat/nextpnr-xilinx.git
cd nextpnr-xilinx
git submodule init
git submodule update
# we skip some of the prjxray steps since we dont use vivado
cd ..
git clone git@github.com:SymbiFlow/prjxray.git
cd prjxray
git submodule update --init --recursive
sudo apt-get install cmake
make build
# sudo apt-get install virtualenv python3 python3-pip python3-virtualenv python3-yaml python3.8-venv
# make env
sudo -H pip3 install -r requirements.txt

cd ../nextpnr-xilinx

# if you get errors about boost
sudo apt-get install libboost-dev libboost-filesystem-dev libboost-thread-dev libboost-program-options-dev libboost-python-dev libboost-dev libboost-all-dev
# if you get errors about eigen
sudo apt install libeigen3-dev



cmake -DARCH=xilinx -DBUILD_GUI=no -DBUILD_PYTHON=no -DUSE_OPENMP=No .
make
python3 xilinx/python/bbaexport.py --device xc7a100tcsg324-1 --bba xilinx/xc7a100t.bba
./bbasm -l xilincx/xc7a100t.bba xilinx/xc7a100t.bin

sudo apt install openocd
```

Test on your hardware with
```
# plug in arty to computer over usb
# Might need to unplug and plug in if not found
# also need to install ftdi VCP drivers https://ftdichip.com/drivers/vcp-drivers/
# linux driver install guide says linux kernel has VCP built in https://ftdichip.com/wp-content/uploads/2020/08/AN_220_FTDI_Drivers_Installation_Guide_for_Linux-1.pdf
cd ~/cherry/cherrycore
./test_a7100t_relu.sh
```

### Setup Development Environment
1. Clone this repo and pull submodules
```sh
git clone https://github.com/evanmays/cherrycore
cd cherrycore
git submodule update --init --recursive
 ```
2. Synthesize then place and route a module (in this example, the regfile)
```sh
/usr/local/bin/yosys -p "synth_xilinx -flatten -nowidelut -family xc7 -top regfile; write_json attosoc.json" ../core/Memory/regfile.sv
~/Desktop/nextpnr-xilinx/nextpnr-xilinx --freq 50 --chipdb ~/Desktop/nextpnr-xilinx/xilinx/xc7a100t.bin --xdc ../arty.xdc --json attosoc.json --write attosoc_routed.json --fasm attosoc.fasm
```


# Superscalar Notes

We can cheat on the superscalar. All deep learning programs have lots of loops (to tile the tensors they are computing on), and each iteration of the loop can be run independently. Kernel programmer will add an annotation to their loop when it's OK to execute the iterations out of order.

Example

```python
# Slow, in order
for i in range(2):
     load
     load
     matmul
     store

# Fast, out of order
for i in cherry_range(2):
     load
     load
     matmul
     store
```
Instead of executing load, load, matmul, store, load, load, matmul, store. We will do some time multiplexing (round robin threads) on each loop iteration. We execute, load, load, load, load, matmul, matmul, store, store. This hides the latency. NVIDIA does a similar thing but they have threads and warps and too many abstractions. Our "threads" are implicit. It takes a day to learn CUDA, it takes an hour to learn cherrylang.

This is dirt cheap to implement in hardware. Cherry 2 will have under a single percent dedicated to this control logic.

Superscalar implementation in `experiments/superscalar.py`. Can play around with different latencies for matmul or memory accesses. Can also play around with different superscalr widths. In hardware, increasing superscalar width costs us extra regfile size. Super scalar width 16 causes regfile to be about 1% of the total SRAM area.

More info (and example code for `cherry_range()` in the compiler section.

# Compiler

Basic example in `experiments/compiler`

Compiles code written in python to the Cherry ISA.

Take code from tiny grad, add a `@cherry_program` decorator to a function and replace a `for i in range(n)` with `for i in cherry_range(n)`.

`cherry_range()` the Cherry device can run the loop iterations out of order and concurrently. So the loop body iterations must be independent. Usually this means two iterations must not rely on eachothers register data. This helps with latency.

This is easy because loop iteration only affects memory addresses and strides which are both linear functions of loop iteration variables. The control unit takes care of loop instructions and address calculation as a linear function of the loop variables.

Programs must be recompiled if their input tensors change shape. So if you have 3 matrices, A, B, C.

```python
# A shape is (10,100)
# B shape is (100,200)
# C shape is (200,10)
A @ B @ C # matrix multiply twice
```
This requires two matmul programs uploaded to Cherry device. One is for input tensors of shape `(10,100)` and `(100,200)` the other is for input tensors of shape `(100,200)` and `(200,10)`. Of course, both programs that were uploaded had the same high level source code written in python.

A reference compiler and standard library of cherry programs will be open source. It should have respectable performance. If the community wants more performance, someone can write new programs and new compiler since the assembly language and device drivers are all open source.

There's todo's sprawled around the `experiments/compiler` folder. Some larger projects

Migrating to c/c++ compiler/assembler.
* Rewrite the sympy library in c or c++. Just need the parts that we use.
* Rewrite the bit packing library in c or c++. Just need the parts that we use.
* Need to think about how we can have an interface as nice as `cherry_range` in c/c++. Maybe need custom intepreter so programs can still be written in a pseudo-python. Maybe just don't move the cherry program frontend to c++, leave it as python.

Usability improvements
* Notify user when they try to access a register outside of a `cherry_range` loop
* Notify user that appears to not be respecting cherry_range loop iteration independence property.
* Write a script that auto finds the best spot for a `cherry_range` to go. This can assist noobs
* Write good error messages for all the `cisa_*` functions
* Document all the things

```python
@cherry_program
def matmul(A):
     # Each iteration of this loop has no dependency on a previous iteration
     # Therefore, we use cherry_range to run the iterations in parallel
     for i in cherry_range(np.prod(A.shape)):
          load
          relu
          store
```
