#!/usr/bin/env python3
from compiler import cherry_program, cisa_load, riski_unop, cisa_store, SZ, cherry_range, KernelGhostTensor, KernelGhostOutputTensorBuilder, Slot, Reg, cisa_mem_read, cisa_mem_write
import numpy as np

# ==== Define your programs ====

@cherry_program(title="Relu")
def cherry_relu(x: KernelGhostTensor, output: KernelGhostOutputTensorBuilder):
    output.set_shape(x.shape)
    if x.slot_if_on_chip == None:
        for i in cherry_range(0, np.prod(x.shape), SZ*SZ):
            cisa_mem_read(x.main_memory_address + i, Slot.SINGLE_TILE, 0)
            cisa_load(Slot.SINGLE_TILE, 0, Reg.MATMUL_INPUT)
            riski_unop("relu")
            cisa_store(Slot.PRIVATE_TILE_ADDRESSABLE_0, i, Reg.MATMUL_OUTPUT)
            cisa_mem_write(output.main_memory_address + i, Slot.PRIVATE_TILE_ADDRESSABLE_0, i)
        output.set_on_chip_slot(Slot.PRIVATE_TILE_ADDRESSABLE_0)
    # elif x.slot_if_on_chip == Slot.PRIVATE_TILE_ADDRESSABLE_0 or x.slot_if_on_chip == Slot.PRIVATE_TILE_ADDRESSABLE_1

# ==== Run your programs ====

print(cherry_relu(np.ones((1024, 10))))