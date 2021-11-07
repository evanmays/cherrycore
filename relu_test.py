#!/usr/bin/python3

import serial
import numpy as np
import torch
import time

port = "/dev/cu.usbserial-210319B26E8C1"

def make_input(random=True):
    if random:
        input = torch.zeros(10, 5, dtype=torch.float16)
        torch.nn.init.xavier_uniform(input)
        input = input.numpy().astype(np.float16)
    else:
        input = np.array([
            [23123.3, -555.1],
            [-723.9, 6.9]
        ], dtype=np.float16)
    return input

input = make_input(True)

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
    output_numpy = np.frombuffer(output_bytes, dtype='>f2').reshape(input.shape)
    print(output_numpy)
    expected = torch.tensor(input).double().relu().half()
    actual = torch.tensor(output_numpy.astype('<f2'))
    print("PASS" if torch.isclose(expected, actual).all() else "FAIL")