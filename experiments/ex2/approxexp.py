# sollya gave me
# 1.0024760564002856541942676543499554820632451587159 + x * (0.65104678030290901896533320206680356042283098866685 + x * 0.34400110689651967264613148923328547545067869390136)
# 
c_0 = 0x3f805123
c_1 = 0x3f26ab00
c_2 = 0x3eb020ea

# go from 9 to 10 for tf32
def get_mantissa(val):
    return (val >> (23-9)) & 0x1FF

c_0_fixed_point = get_mantissa(c_0)
c_1_fixed_point = get_mantissa(c_1) << 1
c_2_fixed_point = get_mantissa(c_2) << 2

print((c_0_fixed_point))
print((c_1_fixed_point))
print((c_2_fixed_point))