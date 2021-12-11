# Source of truth for bit packing Cherry Instruction Set
from functools import cache
from bitstring import pack, BitArray
from enum import IntEnum
from sympy import expand, symbols, Poly, degree_list
from sympy.core.logic import Not

LOOP_CNT_MAX = 8
APU_CNT_MAX = 8

class _Category(IntEnum):
    MEMORY = 0
    RAM = 1
    PROCESSING = 2
    LOOP = 3
class Reg(IntEnum):
    MATMUL_INPUT = 0
    MATMUL_WEIGHTS = 1
    MATMUL_OUTPUT = 2
    MATMUL_ACC = 3

class UnaryOps(IntEnum):
  RELU = 0
  EXP = 1
  LOG = 2
  GT0 = 3

class BinaryOps(IntEnum):
  ADD = 0
  SUB = 1
  MUL = 2
  DIV = 3
  MULACC = 4
  POW = 5

class ReduceOps(IntEnum):
  SUM = 0
  MAX = 1

def get_processing_category(op):
    if type(op) == UnaryOps:
        return 0
    if type(op) == BinaryOps:
        return 1
    if op == "matmul":
        return 2
    if op == "mulacc":
        return 3
    if type(op) == ReduceOps:
        return 4

def bit_pack_unop_instruction(op: UnaryOps):
    return pack('uint:2, uint:3, uint:2, uint:9', _Category.PROCESSING, get_processing_category(op), op, 0)
def bit_pack_binop_instruction(op: BinaryOps, use_acc: bool):
    return pack('uint:2, uint:3, uint:3, uint:1, uint:7', _Category.PROCESSING, get_processing_category(op), op, use_acc, 0)
def bit_pack_matmul_instruction():
    return pack('uint:2, uint:3, uint:11', _Category.PROCESSING, get_processing_category("matmul"), 0)
def bit_pack_mulacc_instruction():
    return pack('uint:2, uint:3, uint:11', _Category.PROCESSING, get_processing_category("mulacc"), 0)
def bit_pack_reduce_instruction(op: ReduceOps, use_acc: bool, axis: int, count: int):
    return pack('uint:2, uint:3, uint:1, uint:1, uint:2, uint:2, uint:5', _Category.PROCESSING, get_processing_category(op), op, use_acc, axis, count, 0)
def bit_pack_copy_acc_to_output():
    raise NotImplementedError
def bit_pack_zero_acc():
    raise NotImplementedError
def bit_pack_loop_instruction(is_start_loop: bool, is_independent: bool = None, loop_address: int = None):
    assert is_start_loop is not None and type(is_start_loop) == bool
    if is_start_loop:
        assert loop_address < LOOP_CNT_MAX
        assert is_independent is not None and type(is_independent) == bool
    else:
        assert loop_address == None
        assert is_independent == None
    return pack('uint:2, uint:1, uint:1, uint:3, uint:9', _Category.LOOP, is_independent or 0, is_start_loop, loop_address or 0, 0)

def bit_pack_cache_instruction(is_load: bool, apu_address, cache_slot: int, target: Reg, zero_flag: bool = False, skip_flag: bool = False):
    assert apu_address < APU_CNT_MAX
    assert cache_slot < 4
    # Note: strides should be stored in the apu. We need to add support for that
    # Note: height and width should be stored in the apu (need a special max function that takes a specified loop var as input). We need to add support for that
    return pack('uint:2, uint:1, uint:3, uint:2, uint:2, 2*uint:1, uint:4', _Category.MEMORY, is_load, apu_address, cache_slot, target, zero_flag, skip_flag, 0)

def bit_pack_ram_instruction(is_write: bool, cache_apu_address, main_memory_apu_address, cache_slot: int):
    assert cache_slot < 4
    assert cache_apu_address < APU_CNT_MAX
    assert main_memory_apu_address < APU_CNT_MAX
    return pack('uint:2, uint:1, 2*uint:3, uint:2, uint:5', _Category.RAM, is_write, cache_apu_address, main_memory_apu_address, cache_slot, 0)

def bit_pack_program_header(loop_iteration_count: list, loop_jump_amount: list, apu_formulas):
    assert len(loop_iteration_count) == 8
    assert len(loop_jump_amount) == 8
    assert len(apu_formulas) == 8
    loop_ro_data = BitArray()
    for iteration_count, jump_amount in zip(loop_iteration_count, loop_jump_amount):
        loop_ro_data.append(
            pack('uint:18, uint:6', iteration_count, jump_amount)
        )
    assert len(loop_ro_data) == 24 * 8, f"Was actually {len(loop_ro_data)}"
    apu_ro_data = BitArray()
    for linear_formula in apu_formulas:
        coefficients = _sympy_to_list(linear_formula)
        print(coefficients)
        apu_ro_data.append(
            pack('9*int:18', *coefficients) # negatives supported
        )
    assert(len(apu_ro_data) == 8*9*18)
    print("apu part 1", apu_ro_data[:648])
    print("apu part 2", apu_ro_data[648:])
    print("loop      ", loop_ro_data)
    ro_data = loop_ro_data + apu_ro_data
    assert(len(ro_data) == 24*8+8*9*18)
    return ro_data

def bit_pack_entire_program(header: BitArray, instructions: BitArray):
    # 186 byte header. Instructions on average 30 bytes. Maximum of 512 bytes
    # Total program between 188 and 698 bytes.
    # Average program is 216 bytes
    assert(len(header) == 186 * 8)
    assert len(instructions) < 256, f"Program has too many instructions. Max allowed is {256}"
    prog = header + instructions
    return prog


def _sympy_to_list(expr):
    """All the coefficients. ret[-1] is the constant term
    """
    if not expr:
        return [0] * 9
    i, j, k, l, m, n, o, p = symbols('i j k l m n o p')
    sympy_vars = [i, j, k, l, m, n, o, p]
    f = expand(expr)
    f = Poly(f, *sympy_vars)
    l = [f.coeff_monomial(var) for var in sympy_vars]
    l.append(f.nth(*([0] * len(sympy_vars)))) # does this always get the constant term?
    assert len(l) == 9
    return l

# Example
if __name__ == "__main__":
    i, j, k, l, m, n, o, p = symbols('i j k l m n o p')
    h = bit_pack_program_header(
        loop_iteration_count=[3] + [0] * 7,
        loop_jump_amount=[2] + [0] * 7,
        apu_formulas=[
            6 * i,
            None,
            i * 2 + p,
            None,
            2 * l + 3,
            None, None, None
        ]
    )
    y = bit_pack_loop_instruction(is_independent=False, is_start_loop=True, loop_address=0)
    print(y)
    x = bit_pack_ram_instruction(is_write=False, cache_apu_address=2, main_memory_apu_address=4, cache_slot=0)
    print(x)
    a = bit_pack_loop_instruction(is_start_loop=False)
    print(a)
    print("The following is the slow relu prog")
    h = bit_pack_program_header(
        loop_iteration_count=[256] + [0] * 7,
        loop_jump_amount=[6] + [0] * 7,
        apu_formulas=[
            i,
            256 + i,
            512 + i, None, None, None, None, None
        ]
    )
    y = bit_pack_loop_instruction(is_independent=False, is_start_loop=True, loop_address=0)
    print(y)
    x = bit_pack_ram_instruction(is_write=False, cache_apu_address=0, main_memory_apu_address=1, cache_slot=0)
    print(x)
    z = bit_pack_cache_instruction(apu_address=0, cache_slot=0, target=Reg.MATMUL_INPUT)
    print(z)
    w = bit_pack_unop_instruction(op=UnaryOps.RELU)
    print(w)
    z = bit_pack_cache_instruction(apu_address=0, cache_slot=1, target=Reg.MATMUL_OUTPUT)
    print(z)
    x = bit_pack_ram_instruction(is_write=True, cache_apu_address=0, main_memory_apu_address=2, cache_slot=1)
    print(x)
    y = bit_pack_loop_instruction(is_start_loop=False)
    print(y)
