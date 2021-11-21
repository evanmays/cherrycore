#!/usr/bin/python3

import serial
import numpy as np

port = "/dev/cu.usbserial-210319B26E8C1"

SZ = 1
BYTES_PER_FLOAT = 2
BYTES_PER_HEADER = 1
AMOUNT_READ = BYTES_PER_HEADER + SZ * BYTES_PER_FLOAT


class PinnedDeviceMemorySpace():
    def __init__(self):
        self.pinned_mem = np.zeros((128,))
        max_attempts = int(4e3)
        success = False
        with serial.Serial(port, timeout=4,baudrate=4800) as ser:
            # empty out any remnants of the buffers in pyserial and ftdi chip
            for _ in range(max_attempts):
                print(_)
                try:
                    if len(ser.read(AMOUNT_READ)) == 0:
                        success = True
                        break
                except:
                    success = True
                    break
        assert success, f"Failed, maybe you forgot to turn the on-device switch up"
        print("Initialized host memory. You may now start running chip (push on-device switch down)")
    
    def start(self):
        with serial.Serial(port, timeout=4,baudrate=4800) as ser:
            while True:
                output_bytes = ser.read(AMOUNT_READ)
                if len(output_bytes) == 0:
                    continue
                output_numpy = np.frombuffer(output_bytes[BYTES_PER_HEADER:], dtype='>f2')

                # Check command has write flag on
                write_flag = int(output_bytes[0]) >> 7
                if write_flag:
                    # Check command has correct memory address
                    write_host_addr = int(output_bytes[0]) & 0x7F
                    assert write_host_addr == 120
                    # Check float value
                    self.pinned_mem[write_host_addr:write_host_addr+1] = output_numpy
                else:
                    pass #TODO: support read commands here and on chip
                print(self.pinned_mem)
    # TODO: support tinygrad creating a new device buffer and moving data to pinned_mem (t.to_gpu())
    # TODO: support tiny grad moving data from pinned_mem to "cpu" land (t.to_cpu())

PinnedDeviceMemorySpace().start()