#!/usr/bin/python3

import serial
import numpy as np
import time

port = "/dev/cu.usbserial-210319B26E8C1"

SZ = 1
BYTES_PER_FLOAT = 2
BYTES_PER_HEADER = 1
BYTES_PER_BODY = SZ * SZ * BYTES_PER_FLOAT


class PinnedDeviceMemorySpace():
    def __init__(self):
        self.pinned_mem = np.zeros((128,), dtype=np.float16)
        self.pinned_mem[120] = 15.0
        max_attempts = int(4e3)
        success = False
        with serial.Serial(port, timeout=4,baudrate=4800) as ser:
            # empty out any remnants of the buffers in pyserial and ftdi chip
            for _ in range(max_attempts):
                # print(_)
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
                header_bytes = ser.read(BYTES_PER_HEADER)
                if len(header_bytes) == 0:
                        continue
                assert len(header_bytes) == BYTES_PER_HEADER, f"read {header_bytes}"
                # Check command has correct memory address
                host_addr = int(header_bytes[0]) & 0x7F
                assert host_addr == 120, f"received {host_addr}"
                # Check if read or write
                write_flag = int(header_bytes[0]) >> 7                

                if write_flag:
                    body_bytes = ser.read(BYTES_PER_BODY)
                    assert len(body_bytes) == BYTES_PER_BODY, f"read {body_bytes}"
                    # print(body_bytes)
                    output_numpy = np.frombuffer(body_bytes, dtype='>f2')
                    self.pinned_mem[host_addr:host_addr+SZ*SZ] = output_numpy
                    print(self.pinned_mem)
                else:
                    np_dat = self.pinned_mem[host_addr:host_addr+SZ*SZ]
                    bytes_dat = np_dat.byteswap().tobytes()
                    for i in range(len(bytes_dat)):
                        byte = bytes_dat[i:i+1] # non sliced access isn't what you expect
                        time.sleep(0.1) # lol
                        ser.write(byte)
    # TODO: support tinygrad creating a new device buffer and moving data to pinned_mem (t.to_gpu())
    # TODO: support tiny grad moving data from pinned_mem to "cpu" land (t.to_cpu())

PinnedDeviceMemorySpace().start()