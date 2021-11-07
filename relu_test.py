#!/usr/bin/python3

import serial
import numpy as np
import time

port = "/dev/cu.usbserial-210319B26E8C1"

input = np.array([
    [23123.3, -555.1],
    [-723.9, 6.9]
], dtype=np.float16)
print(input)
input_bytes = input.byteswap().tobytes()

out = np.frombuffer(input_bytes, dtype=np.float16).reshape(input.shape)
# assert (input == out).all()

with serial.Serial(port, timeout=4,baudrate=4800) as ser:
    
    count = 0
    for i in range(len(input_bytes)):
        byte = input_bytes[i:i+1]
        time.sleep(0.1) # lol
        ser.write(byte)

    output_bytes = ser.read(len(input_bytes))
    
    # print("Sent:    ", input_bytes, "\nGot back:", output_bytes)
    print(np.frombuffer(output_bytes, dtype='>f2').reshape(input.shape))