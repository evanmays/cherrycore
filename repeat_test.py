#!/usr/bin/python3

import serial
import numpy as np
import math
# import torch
import time

port = "/dev/cu.usbserial-210319B26E8C1"

AMOUNT_READ = 3
success = 0
count = 0
for t in range(30):
    
    with serial.Serial(port, timeout=4,baudrate=4800) as ser:
        output_bytes = ser.read(AMOUNT_READ)
        print(output_bytes) # should be the hex values for 0xF8 0x21 0x55
        output_numpy = np.frombuffer(output_bytes[1:3], dtype='>f2')
        print(output_numpy)

        # Check command has write flag on
        write_flag = int(output_bytes[0]) >> 7
        print("PASS" if write_flag else "FAIL write flag")
        # Check command has correct memory address
        write_host_addr = int(output_bytes[0]) & 0x7F
        print("PASS" if write_host_addr == 120 else "FAIL host addr")
        # Check float value
        print("PASS" if math.isclose(float(output_numpy), 0.010414, abs_tol=0.01) else "FAIL float data")

        success += 1 if math.isclose(float(output_numpy), 0.010414, abs_tol=0.01) else 0
        count += 1
    print(t)
    print(success, count, success / count)
    time.sleep(10)
    