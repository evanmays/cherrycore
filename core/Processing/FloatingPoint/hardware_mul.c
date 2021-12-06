#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>
#include <fenv.h>

typedef enum {
  TF32 = 0,
  BF16 = 1,
  CHERRY_FLOAT = 2,
} HardwareMulType; 

uint32_t f2u(float f) {
  union {
    float f;
    uint32_t u;
  } f2u = { .f = f };
  return f2u.u;
}
float u2f(uint32_t u) {
  union {
    float f;
    uint32_t u;
  } u2f = { .u = u };
  return u2f.f;
}

float hardwareMul(float a, float b, HardwareMulType mulType) {
  FILE *fp;
  char path[1035];

  char *prog = calloc(1024, sizeof(char));
  
  // compile as iverilog -g2012 -o hardware_mul Mul_Run.sv
  if (!sprintf(prog, "./hardware_mul +a=%x +b=%x +type=%d", f2u(a), f2u(b), mulType)) {
    exit(1);
  }
  // printf("prog: %s\n", prog);

  fp = popen(prog, "r"); // maybe cleaner as system verilog DPI
  if (fp == NULL) {
    printf("Failed to run command\n" );
    exit(1);
  }
  uint32_t ret;
  if (fscanf(fp, "ret %x", &ret) == 1) {
    pclose(fp);
    return u2f(ret);
  } else {
    printf("Failed to read hex");
    pclose(fp);
    exit(1);
  }
}