from bitstring import pack, BitArray
from enum import IntEnum
from sympy import expand, symbols, Poly, degree_list

LOOP_CNT_MAX = 8

class _Category(IntEnum):
    MEMORY = 0
    RAM = 1
    PROCESSING = 2
    LOOP = 3

def bit_pack_processing_instruction(target, src, is_default):
    raise NotImplementedError
    # TODO: assert the params valid
    return pack('uint:2, 2*uint:2, uint:1, uint:8', _Category.PROCESSING, target, src, is_default, 0)

def bit_pack_loop_instruction(is_start_loop: bool, is_independent: bool = None, loop_address: int = None):
    assert is_start_loop is not None and type(is_start_loop) == bool
    if is_start_loop:
        assert loop_address < LOOP_CNT_MAX
        assert is_independent is not None and type(is_independent) == bool
    else:
        assert loop_address == None
        assert is_independent == None
    return pack('uint:2, uint:1, uint:1, uint:3, uint:9', _Category.LOOP, is_independent or 0, is_start_loop, loop_address or 0, 0)

def bit_pack_cache_instruction(apu_address, target, height, width, zero_flag, skip_flag):
    # TODO: assert the params valid
    raise NotImplementedError
    return pack('uint:2, uint:3, 3*uint:2, 2*uint:1, uint:2', _Category.MEMORY, apu_address, target, height, width, zero_flag, skip_flag, 0)

def bit_pack_ram_instruction(is_write: bool, cache_apu_address, main_memory_apu_address, cache_slot):
    assert cache_slot < 4
    assert cache_apu_address < 8
    assert main_memory_apu_address < 8
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