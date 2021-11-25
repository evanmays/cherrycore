# Cherry Core

![Indicator of if Unit Tests workflow are passing](https://github.com/evanmays/cherrycore/actions/workflows/SVUT.yml/badge.svg)

A deep learning training core. Start tiny with just a control unit, memory, and ReLU. Then, get bigger and better. Every version should work on real hardware. The goal is to put the AS in ASIC... it's not even turing complete, but it trains neural nets faster and gets more done on a single chip.

ISA in Cherry ISA.pdf
Superscalar notes below

Same cache bandwidth as a 3090 but due to the larger tile size we have 4x the arithmetic intensity on cache transfers. So, once data is on chip, the programs complete in a quarter the time.

There are 3 functional units all pipelined individually so they may in total complete 3 instructions per cycle. The first functional unit deals with cisa_mem_write and cisa_mem_read instructions. It's transfering data between device memory and device cache. The second functional unit supports cisa_load and cisa_store. It transfers data between device cache and the regfile. The third functional unit deals with all of our arithmetic insturctions. There are your cisa_matmul, cisa_relu, etc.

To feed the three pipelines 3 instructions per cycle, we have an instruction queue. On the other end of that queue is an out of order superscalar control unit. This unit is much simpler than most other superscalars. It utilizes the knowledge that ML programs are all loops. The programmer can replace a python range() function with cherry_range() and our superscalar unit will then treat each loop body as a thread allowing it to parallelize things. Since the programs aren't turing complete, we can make a perfect branch predictor and prefetch all cisa_mem_read instructions. There's also a program cache that can hold all the programs a forward and back pass would need (a few KB). And a program exection queue which allows the host device to schedule programs.

4 slots of memory, each one has different access pattern support. Need to find a balance of slots that do 0D, 1D, 3D and ND striding. The trick with ND striding will be to signifantly reduce cache bandwidth. So, maybe a programer can load a 32x32 tile (1024 elements) with 1D striding. But, if they want 3D striding then they can only load a 3x3x3 cube (27 elements). Notice we went from 1024 elements to 27. But if you had kept 1D striding you probably woudn't be able to get max utilization on the 1024 elements anyway. Supporting arithmetic on cubes instead of tiles should be cheap although we can probably only afford 1 or 2 cube sizes options. Need more example conv2d programs to pick exactly what we want to support here. Perhaps on cherry 3 one slot should be shared across cores and broadcast its reads to all cores.


# Cherry 1 Stages

1. Tiny Cherry 1, does 1 relu per cycle (50 MFLOPs) in simulator and on physical a7-100t. It's just scaffolding so rest of work can be done in parallel.
2. Small Cherry 1, does 6.4 GFLOPs with support for entire ISA in simulator and on physical a7-100t
3. Big Cherry 1, works on physical $7500 Alveo u250 fpga (or equivalent)

Original Cherry 2 and 3 master plan [written by geohot here](https://github.com/geohot/tinygrad/tree/master/accel/cherry). But I have some tweaks

1. Cherry 2 stays the same. It's just a tapeout of the Big Cherry 1
2. Cherry 3 is the AI Training Card for your desktop and for real production model training (no GPT-3 fine tuning sorry). It's got half a petaflop peak TF32 performance and high flop utilization. 8 cores instead of 16. 1024 GB/s VRAM instead of 512.

# How to get to working Tiny Cherry 1

To get to a state where we have scaffolding. Just want a chip that supports loop, relu, and sram instructions. With SZ=1. So only operating on a single float at a time.

Just finish these last 4 things

* **Make DMA engine**. Allow it to be driven by host PC. Cherry device sends some kind of ACK message back to host. Needs to access data cache, program cache, and program execution queue (maybe execution queue should be over uart?).
* **Make instruction queues** that check for hazards on insert. model after `superscalar.py`
* **Make a floating point ReLU**. Probably 10 lines of verilog. We want a simple processing instruction so we can end to end test without worrying about if this is correct or not. More arithmetic will come later.
* **Top**. Create `module top_tiny` that wires all the pieces together. Now we can test training on mnist with the relus done on cherry verilator simulator.

# Cherry Inference Chip Works on a7100t

This chip takes in a fp16 over uart, then applies the ReLU function, then sends the fp16 back over uart. We have this working with numpy arrays.

Tested on macOS plugged in to a7100t over usb.

Prerequisites aren't documented but the script that synthesizes, place-n-routes, uploads the bitstream, and runs a test python program is `./test_a7100t_relu.sh`

It does something like 100 ReLUs a second. will be scaffolding for making tiny cherry 1

# Getting Started

### Prerequisites (MacOS & linux... sry Windows)
* icarus-verilog 
* yosys
* nextpnr-xilinx if you want to place and route to check for timing
```sh
brew install icarus-verilog # Yes, even on linux
# add yosys
# add nextpnr-xilinx which has way more steps than you'd expect
```

### Setup Development Environment
1. Clone this repo
```sh
git clone https://github.com/evanmays/cherrycore
cd cherrycore
 ```
2. Synthesize then place and route a module (in this example, the regfile)
```sh
/usr/local/bin/yosys -p "synth_xilinx -flatten -nowidelut -family xc7 -top regfile; write_json attosoc.json" ../core/Memory/regfile.sv
~/Desktop/nextpnr-xilinx/nextpnr-xilinx --freq 50 --chipdb ~/Desktop/nextpnr-xilinx/xilinx/xc7a100t.bin --xdc ../arty.xdc --json attosoc.json --write attosoc_routed.json --fasm attosoc.fasm
```

# TODO

* Write verilog. Search for the word TODO throughout this README
* Fix unaligned loads/stores (I think this is good now, at least acceptable)
* Clean up this repo
* Improve this readme


# Superscalar Notes

We can cheat on the superscalar. All deep learning kernels have lots of loops (to tile the tensors they are computing on), and each iteration of the loop can be run independently. Kernel programmer will add an annotation to their loop when it's OK to execute the iterations out of order.

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
Instead of executing load, load, matmul, store, load, load, matmul, store. We will do some time multiplexing on each loop iteration. We execute, load, load, load, load, matmul, matmul, store, store. This hides the latency. NVIDIA does a similar thing but the CUDA programmer must think about threads and warps. Our "threads" are implicit.

This is super cheap to implement in hardware. Hopefully, under 1,500 of our 64,000 luts.

Superscalar implementation in `experiments/superscalar.py`. Can play around with different latencies for matmul or memory accesses. Can also play around with different superscalr widths. In hardware, increasing superscalar with is almost free for us on FPGA.

More info (and example code for `cherry_range()` in the compiler section.

We also take advantage of the immutability of tensor objects to prefetch data. More here [memory model doc](memory_model.md)

# Tensor Cores

These all should be straightforward but annoying to get to IEEE specification.

They can be pipelined. Ideal latency is 3 or less cycles. Every doubling of latency requires us to double our superscalar width which means double the L0 registers which means double the processing core multiplexer which means we not happy.

* Test floating point multiply
* Write & test floating point add
* Write & test floating point fused multiply add (FMA) (http://jctjournals.com/May2016/v5.pdf)
* Use fused multiply accumulate (FMA) for the matmul and mulacc
* Write & test Relu (should be an easy intro, save for noobs)
* Write & test GT0 (should be an easy intro, save for noobs)
* Write & test the other unops and binops

# Notes on Memory system

Programmer manually cache. They are aided by our runtime telling them when a matrix is in cache already or not. They write two programs. One for if a tensor is in cache, another for if the tensor is not in cache.

Strided Memory
8 million elements (20MB) = 23-bit address path

We want to support a load/store instruction into 32x32 matrix register (2432 bytes). The programmer can access 4 of these registers.

Use some hash function on the addresses to avoid "bank conflicts", can upper bound to probabilisticly 1.2 cycles per matrix load with stride x as 0 or 1.

Memory ports won't truly support stride x greater than 1 but Conv2d is the only thing using that. And only when H and W are not both 1. We will have the memory accesses get progressively slower as H and W increase, eventually it asymptotes. It will still be higher bandwidth than nvidia even at slowest point. But why waste the transistors supporting a stride x > 1 when the only one who needs it is convolutions.

If user tries stride y as 1 and stride x > 1, then we just transpose the matrix during the load.

On Big Cherry 1
z=min(stride x, stride y)
z=0 is max efficiency
z=1 is max efficiency
z=4 is 4x slower
z=9 is 8x slower
z>=16 is 16x slower

Convolution with H,W=3 is H*W=Z=9 so 8x slower. Convolution with H,W=1 is Z=1 so max bandwidth.

Non Strided Memory

8 million elements (20MB) = 23-bit address path

Processor can only read from here, DMA can only write.

No strides on chip

Support a load (no store) instruction into 32x32 matrix register. The load instruction can specificy strides but they happen over time. The data is loaded from the DMA while the program is executing. If the data isn't loaded yet, program stalls.

Since non strided, bank conflicts don't happen.

Apple has performance cores and efficiency cores. One might call the other memory, strong cache, and this is weak cache.

All cache slots (strong and weak, strided and non strided) Are split into 4 slots. Each slot can hold one tensor.

If user wants their cherry program to output multiple tensors, they can store one tensor in local cache, and queue the rest of the tensors to go to DMA.

# Notes on ALU

matmul/mulacc are the big ones, 65536 FLOPS and 2048 FLOPS respectively

Have to think this through more with the reduce instructions too.

It's okay if the matmul takes multiple cycles I think, but the mulacc would be nice to be one.

TODO
* add tests for matmul
* add remaining vector ops
* add reduce ops

# Notes on mini edition in 100T

16x16 registers (608 bytes), 256 FMACs (does it fit)

* 128k elements = 17-bit address path
* rs1 = 2x4-bit masks + 17-bit address
* rs2 = 2x16-bit strides

# Compiler

Basic example in `experiments/compiler`

Compiles code written in python to the Cherry ISA.

Take code from tiny grad, add a `@cherry_kernel` decorator to a function and replace a `for i in range(n)` with `for i in cherry_range(n)`.

`cherry_range()` the Cherry device can run the loop iterations out of order and concurrently. So the loop body iterations must be independent. This helps with latency. This is easy because loop iteration only affects memory addresses and strides which are both linear functions of loop iteration variables. Loop controller and it's APUs (Address Processing Units) take care of this.

If max instruction latency is 4, then we want our superscalar to execute loop iterations instructions concurrently.

Programs must be recompiled if their input tensors change shape. So if you have 3 matrices, A, B, C.

```python
# A shape is (10,100)
# B shape is (100,200)
# C shape is (200,10)
A @ B @ C # matrix multiply twice
```
This requires two matmul programs uploaded to Cherry device. One is for input tensors of shape `(10,100)` and `(100,200)` the other is for input tensors of shape `(100,200)` and `(200,10)`. Of course, both programs that were uploaded had the same high level source code written in python.

If the community sees a lot of people multipliying groups of 3 matrices, maybe someone will write a high level python program to multiply 3 matrices instead of 2. Then this code would only need to compile and be uploaded to the cherry once. This should be easy since writing code for Cherry is easy if you have a good algorithm. The new kernel even saves memory bandwidth. I suspect memory bandwidth will be a common usecase for creating new kernels. 

These kernels can be open sourced and shared in a community kernel repo.

Details on the memory model when writing cherry programs that have multiple inputs (and multiple outputs which are needed for backprop). [memory model doc](memory_model.md)


TODO:
* Support the entire instruction set
* Create assembler
* More todo's in the `experiments/compiler/compiler.py`
* Allow kernels to have metadata saying when to replace another sequence of kernels with the new kernel. i.e.

```python
@cherry_kernel
def matmul_two(A, B):
     for i in cherry_range(A.shape * B.shape):
          load
          load
          matmul
          store

@cherry_kernel(sequence_to_replace[matmul_two, matmul_two])
def matmul_three(A, B, C):
     for i in cherry_range(A.shape * B.shape * C.shape):
          load
          load
          matmul
          load
          matmul
          store
```

# DMA Notes

On small cherry 1 (mini edition), memory has 5 ports of width 18*4. 4 ports are for running kernels, 5th port is for DMA. 4 ports have priority. 5th port stalls a bunch. The 5th port can use reorder buffer to prevent stalls. Reorder buffer length 2 with guaranteed reorder by no more than 1 position. Simple algorithm: Use a single bit to take note on when a dma op has been ignored for one cycle or not. This should get us to maybe 5% stall rate. Can increase decode width to 4 for ~0% stall rate. I'm just guestimating on this percent but it feels accurate.

Small Cherry 1
`100e6` bits per second @ 50MHz is 2 bits per cycle. Can't even use full 5th port. Must have a hardware generated mask

Big Cherry 1
`8*12e9` bits per second @ 500MHz is 192 bits per cycle. But now port is `16*18=288` bits wide. Still can't use full port. Must have a hardware generated mask

Cherry 2
`8*12e9` bits per second @ 500MHz is 192 bits per cycle. But now port is `32*18=576` bits wide. Still can't use full port. Must have a hardware generated mask. Even with next gen PCIE still need mask.

TODO:
* Can we add this 5th port? Does a mask work? Can we keep the fifth port and other DMA stuff under 5% LUT usage?
