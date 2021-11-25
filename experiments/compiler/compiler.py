import numpy as np
from sympy import expand, Symbol
import functools
from dataclasses import dataclass
from typing import Optional, Tuple
from inspect import signature
from enum import Enum

# ==== Compiler Constants ====

APU_LIMIT = 16
loop_variables = ['i', 'j', 'k', 'l', 'm', 'n', 'o', 'p']

class Slot(Enum):
  PRIVATE_TILE_ADDRESSABLE_0 = 0 # Private to each core. Addressable by SZxSZ tile. Non strided.
  PRIVATE_TILE_ADDRESSABLE_1 = 1 # Private to each core. Addressable by SZxSZ tile. Non strided.
  SINGLE_TILE = 2 # Holds just one tile.
  SHARED_STRIDED = 3 # Shared across the cores. Used for storing model.parameters(). Strided
  

class DeviceVersion(Enum):
    SMALL_CHERRY_ONE = "small_cherry_one"
    BIG_CHERRY_ONE = "big_cherry_one"

address_bits = {
    DeviceVersion.SMALL_CHERRY_ONE: {
        Slot.SHARED_STRIDED: 14, # cache line is 4 elements and we can hold 65,536. First 4 bits select the bank.
        Slot.SINGLE_TILE: 0,
        Slot.PRIVATE_TILE_ADDRESSABLE_0: 11, # cache line is 16 elements and we can hold 32,768
        Slot.PRIVATE_TILE_ADDRESSABLE_1: 11  # cache line is 16 elements and we can hold 32,768
    },
    DeviceVersion.BIG_CHERRY_ONE: {
        Slot.SHARED_STRIDED: 18,
        Slot.SINGLE_TILE: 0,
        Slot.PRIVATE_TILE_ADDRESSABLE_0: 11,
        Slot.PRIVATE_TILE_ADDRESSABLE_1: 11
    }
}

size_for_version = {
    DeviceVersion.SMALL_CHERRY_ONE: 4,
    DeviceVersion.BIG_CHERRY_ONE: 16
}

# ==== Importable Constants ====
CURRENT_DEVICE_VERSION = DeviceVersion.SMALL_CHERRY_ONE
SZ = size_for_version[CURRENT_DEVICE_VERSION]
class Reg(Enum):
    MATMUL_INPUT = 0
    MATMUL_WEIGHTS = 1
    MATMUL_OUTPUT = 2
    MATMUL_ACC = 3

# ==== Compiler state ====

is_jit_compiling_active = False
loop_var_next = 0

loop_ro_data = [False] * len(loop_variables) # We could actually make this larger if we want
apu_ro_data = [False] * APU_LIMIT
next_apu = 0
program = []

# ==== Internal stuffs ====

@dataclass
class GhostTensor():
    shape: Tuple[int]
    is_model_param: bool
    slot_if_on_chip: Optional[Slot]
    main_memory_address: Optional[int]

class GhostOutputTensorBuilder():
    def __init__(self):
        self.slot_if_on_chip = None
        self.main_mem_addr = None
    @property
    def main_memory_address(self):
        if self.main_mem_addr == None:
            # malloc enough space for shape. for now, force shape to be set first
            self.main_mem_addr = 0
        return self.main_mem_addr
    def set_on_chip_slot(self, slot: Slot):
        self.slot_if_on_chip = slot
    def set_shape(self, shape: Tuple[int]):
        self.shape = shape
    def to_ghost_tensor(self):
        return GhostTensor(shape=self.shape, is_model_param=False, slot_if_on_chip=self.slot_if_on_chip, main_memory_address=self.main_mem_addr)
    def convert_to_tensor(self):
        # assert calling from this file
        # TODO: makes a new tinygrad tensor with a CherryBuffer
        return self
    def assert_complete(self):
        _assert(self.shape, f"Your output tensor didn't set a shape: {self}")

class CherryError(Exception):
    pass

def _assert(target_true, error_msg):
    if not target_true:
        raise CherryError(error_msg)

def assert_program_active(func):
    @functools.wraps(func)
    def f(*args, **kwargs):
        if not is_jit_compiling_active:
            raise CherryError(f"JIT active status: {is_jit_compiling_active}. Try calling our cisa_* instructions in a @cherry_program function.")
        func(*args, **kwargs)
    return f


# ==== Importable accelerator functions ====

def cherry_program(func=None, title=None, replaces=None):
    if not func:
        return functools.partial(cherry_program, title=title)
    @functools.wraps(func)
    def f(*args, **kwargs):
        global loop_ro_data, apu_ro_data, program, loop_var_next, next_apu, is_jit_compiling_active
        is_jit_compiling_active = True

        # reset variables
        prev_prog_high_priority_outputs = []
        loop_ro_data = [False for _ in range(len(loop_ro_data))]
        apu_ro_data = [False for _ in range(len(apu_ro_data))]
        program = []
        loop_var_next = 0
        next_apu = 0

        # Convert from real tensors to ghost tensors
        ghost_args = []
        print(signature(func).parameters.values())
        cherry_program_arg_types = [p.annotation for p in signature(func).parameters.values()]
        assert len(cherry_program_arg_types) == len(args) + 1
        for i, tensor in enumerate(args):
            if isinstance(tensor, np.ndarray):
                if cherry_program_arg_types[i] == GhostTensor:
                    t = GhostTensor(shape=tensor.shape, is_model_param=False, slot_if_on_chip=None, main_memory_address=id(tensor)) # set is_model_param based on tiny grad tensor. Set slot_if_on_chip based on tiny grad tensor. Value in tiny grad tensor must be set from ghost builder
                    ghost_args.append(t)

        for arg_type in cherry_program_arg_types:
            if arg_type == GhostOutputTensorBuilder:
                out = GhostOutputTensorBuilder()
                ghost_args.append(out)
                ret = out

        # Run program
        func(*(tuple(ghost_args)), **kwargs)
        
        # Assert program did its job
        ret.assert_complete()

        # Finish creating program
        header = f"""Title:          {title}
loop_ro_data:   {loop_ro_data}
apu_ro_data:    {apu_ro_data}

body:
"""
        print(header + "\n".join(program))
        is_jit_compiling_active = False
        return ret.convert_to_tensor()
    return f


def cherry_range(*args):
    """Want loops that run fast? Replace for `range(n)` with `cherry_range(n)`"""
    global loop_var_next
    # TODO: Create a CherryException class
    _assert(loop_var_next < len(loop_variables), f"You exceeded the maximum number of loops allowed: {len(loop_variables)}. Use less cherry_range loops.")
    program.append(f"loop_start {loop_var_next}")

    if len(args) == 1:
        slope = 1
        y_intercept = 0
        iterations = args[0]
    elif len(args) == 2:
        slope = 1
        y_intercept = 0
        _assert(False, "TODO: support 2 args")
    elif len(args) == 3:
        slope = args[2]
        y_intercept = args[0]
        iterations = (args[1]-args[0]) // args[2]
        loop_unroll_count_remainder = (args[1]-args[0]) % args[2] # TODO: support non zero remainder. Just unroll loop
        _assert(loop_unroll_count_remainder == 0, "TODO: Support this as nonzero remainder. unroll the loop this many times.")

    loop_ro_data[loop_var_next] = iterations
    loop_var_cur = loop_var_next
    loop_var_next += 1
    yield slope * Symbol(loop_variables[loop_var_cur]) + y_intercept
    program.append("loop_end")


@assert_program_active
def cisa_unop(op):
    program.append(op)

@assert_program_active
def cisa_binop(op):
    program.append(op)

def use_apu(address) -> int:
    # TODO: make a special apu that is just always 0 for when the formula is 0
    # TODO: support combining of multiple APUs with same formula. If expand(new_address - old_address) == 0 don't insert and use old_address position
    # TODO: Get the gradient w.r.t. each loop variable (Can check if linear function if all of these are constant or check linearity by other means)
    global next_apu
    _assert(next_apu < APU_LIMIT, f"All available APUs used up. Try using less load store instructions. Or having load store instructions share the same formula to calculate their address and strides.")
    address_formula = expand(address) # TODO: assert linear
    apu_ro_data[next_apu] = address_formula
    ret = next_apu
    next_apu += 1
    return ret
    
@assert_program_active
def cisa_load(slot: Slot, address, reg: Reg):
    _assert(address < 2 ** address_bits[CURRENT_DEVICE_VERSION][slot], "Address is too big for the slot type you selected")
    
    # TODO: support rest of cisa_load (previously riski_load) parameters
    # TODO: more asserts that tell user what they are doing wrong
    # TODO: Help the linters understand what we want

    program.append(f"cisa_load {use_apu(address)} {reg} {slot}")


@assert_program_active
def cisa_store(slot: Slot, address, reg: Reg):
    # add assert for address, need to get max possible value for address formula based on the loop iteration counts.
    program.append(f"cisa_store from reg {reg} to slot {slot} apu {use_apu(address)}")

@assert_program_active
def cisa_mem_read(main_memory_address: int, slot: Slot, slot_address: int):
    # add assert for address, need to get max possible value for address formula based on the loop iteration counts.
    program.append(f"cisa_mem_read from main memory addr {main_memory_address} into slot {slot} address apu {use_apu(slot_address)}")

@assert_program_active
def cisa_mem_write(main_memory_address: int, slot: Slot, slot_address: int):
    # need main_memory_address formula to use apu but we just want it to use 18 bit apu and we can add the 64 bit constant elsewhere.
    # add assert for address, need to get max possible value for address formula based on the loop iteration counts.
    program.append(f"cisa_mem_write from slot {slot} address apu {use_apu(slot_address)} to main memory addr {main_memory_address}")