#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>
#include <fenv.h>
#include "hardware_mul.c"

bool AlmostEqualRelative(float A, float B)
{
  if ((A == INFINITY && B == INFINITY) || (A == -INFINITY && B == -INFINITY)) {
    return true;
  }
  if (isnan(A) && isnan(B)) {
    return true;
  }
  // https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
  float maxRelDiff = 0.01;//__FLT_EPSILON__;
  // Calculate the difference.
  float diff = fabs(A - B);
  A = fabs(A);
  B = fabs(B);
  // Find the largest
  float largest = (B > A) ? B : A;

  if (diff <= largest * maxRelDiff)
    return true;
  return false;
}

void assertEqualFloats(int i, float act, float exp, char *funcName, HardwareMulType mulType) {
  if (!AlmostEqualRelative(act, exp)) { //fabs(act - exp) > 0.01)
    printf("\033[0;31mFAILURE %s\n", funcName);
    printf("\033[0;30mmicro test #%d different: act=%f, exp=%f mulType=%d\n", i, act, exp, mulType);
    assert(false);
  }
}
void printsuccess(char *funcName) {
  printf("\033[0;32mSUCCESS %s\n\033[0;30m", funcName);
}

void basic_test_tf32(void) {
  float a, b;
  a = -100.0;
  b = 0;
  for (int i = 0; i < 1024; i++) {
    a += 0.01;
    b += 0.03;
    assertEqualFloats(
      i,
      hardwareMul(a, b, TF32),
      a * b,
      (char *)__func__,
      TF32
    );
  }
}

void infinity_test_all(void) {
  assertEqualFloats(
    0,
    hardwareMul(INFINITY, -20.0, TF32),
    INFINITY * -20.0,
    (char *)__func__,
    TF32
  );
  assertEqualFloats(
    0,
    hardwareMul(INFINITY, -20.0, BF16),
    INFINITY * -20.0,
    (char *)__func__,
    BF16
  );
  assertEqualFloats(
    0,
    hardwareMul(INFINITY, -20.0, CHERRY_FLOAT),
    INFINITY * -20.0,
    (char *)__func__,
    CHERRY_FLOAT
  );
}

void nan_test_all(void) {
  assertEqualFloats(
    0,
    hardwareMul(NAN, -20.0, TF32),
    NAN * -20.0,
    (char *)__func__,
    TF32
  );
  assertEqualFloats(
    0,
    hardwareMul(NAN, -20.0, BF16),
    NAN * -20.0,
    (char *)__func__,
    BF16
  );
  assertEqualFloats(
    0,
    hardwareMul(NAN, -20.0, CHERRY_FLOAT),
    NAN * -20.0,
    (char *)__func__,
    CHERRY_FLOAT
  );
}

void corner_case_test_cherry_float(void) {
  // from https://github.com/dawsonjon/fpu/blob/master/multiplier/run_test.py
  float a, b;
  uint32_t testvec[6] = {0x80000000, 0x00000000, 0x7f800000, 0xff800000, 0x7fc00000, 0xffc00000};
  for (int i = 0; i < 6; i++) {
    for (int j = 0; j < 6; j++) {
      a = u2f(testvec[i]);
      b = u2f(testvec[j]);
      assertEqualFloats(
        6 * i + j,
        hardwareMul(a, b, CHERRY_FLOAT),
        a * b,
        (char *)__func__,
        CHERRY_FLOAT
      );
    }
  }
}

void edge_case_test_cherry_float(void) {
  // from https://github.com/dawsonjon/fpu/blob/master/multiplier/run_test.py
  float a, b;
  uint32_t testvec[6] = {0x80000000, 0x00000000, 0x7f800000, 0xff800000, 0x7fc00000, 0xffc00000};
  for (int i = 0; i < 6; i++) {
    a = u2f(testvec[i]);
    srand(1337);
    for (int j = 0; j < 1000; j++) {
      b = u2f(rand());// not the same across cpu's/implementations. We want to use a library here.
      assertEqualFloats(
        1000 * j + i,
        hardwareMul(a, b, CHERRY_FLOAT),
        a * b,
        (char *)__func__,
        CHERRY_FLOAT
      );
    }
  }
}

int main(void) {
  // #if __APPLE__
  // FE_DFL_DISABLE_SSE_DENORMS_ENV is Mac only. Gcc compiler flags are cross platform
  // fesetenv(FE_DFL_DISABLE_SSE_DENORMS_ENV);
  // #else
  // Haven't tried this one. Internet person says it works for gcc on linux
  // #include <xmmintrin.h> 
  // _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);
  // #endif
  infinity_test_all();
  printsuccess("infinity_test_all");
  nan_test_all();
  printsuccess("nan_test_all");
  corner_case_test_cherry_float();
  printsuccess("corner_case_test_cherry_float");
  edge_case_test_cherry_float();
  printsuccess("edge_case_test_cherry_float");
  basic_test_tf32();
  printsuccess("basic_test_tf32");
  return 0;
}