#include <stdint.h>
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
  if ((A == NAN && B == NAN) || (A == -NAN && B == -NAN)) {
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
    printf("\033[0;30mmicro test %d different: act=%f, exp=%f mulType=%d\n", i, act, exp, mulType);
    exit(1);
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

int main(void) {
  fesetenv(FE_DFL_DISABLE_SSE_DENORMS_ENV);
  basic_test_tf32();
  printsuccess("basic_test_tf32");
  infinity_test_all();
  printsuccess("infinity_test_all");
  nan_test_all();
  printsuccess("nan_test_all");
  return 0;
}