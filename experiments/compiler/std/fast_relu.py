import sys
import os
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.dirname(SCRIPT_DIR))
from assembler import *
i, j, k, l, m, n, o, p = symbols('i j k l m n o p')

# eventually we'll want to rewrite this in higher level language. For now, assembly.
h = bit_pack_program_header(
    loop_iteration_count=[128] + [0] * 7,
    loop_jump_amount=[6] + [0] * 7,
    apu_formulas=[
        i,
        0 + i,
        0 + i, None, None, None, None, None
    ]
)
y = bit_pack_loop_instruction(is_independent=True, is_start_loop=True, loop_address=0)
print(y)
x = bit_pack_ram_instruction(is_write=False, cache_apu_address=0, main_memory_apu_address=1, cache_slot=0)
print(x)
z = bit_pack_cache_instruction(apu_address=0, cache_slot=0, target=Reg.MATMUL_INPUT, is_load=True)
print(z)
w = bit_pack_unop_instruction(op=UnaryOps.RELU)
print(w)
z = bit_pack_cache_instruction(apu_address=0, cache_slot=1, target=Reg.MATMUL_OUTPUT, is_load=False)
print(z)
x = bit_pack_ram_instruction(is_write=True, cache_apu_address=0, main_memory_apu_address=2, cache_slot=1)
print(x)
y = bit_pack_loop_instruction(is_start_loop=False)
print(y)