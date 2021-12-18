#!/usr/bin/python3
import socket
import sys
import numpy as np

SZ = 1
BYTES_PER_FLOAT = 2
BYTES_PER_HEADER = 1
BYTES_PER_BODY = SZ * SZ * BYTES_PER_FLOAT

class PinnedDeviceMemorySpace():
    def __init__(self):
        self.pinned_mem = np.zeros((128,), dtype=np.float16)
        self.pinned_mem[120] = 15.0
        a = 120.0
        for i in range(16, 16+16*4, 4):
            a += 1.0
            self.pinned_mem[i] = a if not i % 16 == 0 else -a
        print("pinned mem start")
        print(self.pinned_mem)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_address = ('localhost', 1337)
        self.sock.connect(server_address)
        # sock.close()
    
    def start(self):
        """
        This causes host computer to listen and
        respond to cisa_mem_* instructions from the cherry device.
        It infinite loops.
        """
        while True:
            header_bytes = self.sock.recv(BYTES_PER_HEADER)
            if len(header_bytes) == 0:
                    continue
            assert len(header_bytes) == BYTES_PER_HEADER, f"read {header_bytes}"
            # Check command has correct memory address
            host_addr = int(header_bytes[0]) & 0x7F
            # assert host_addr == 120, f"received {host_addr}"
            # Check if read or write
            write_flag = int(header_bytes[0]) >> 7
            print("Received", "write request" if write_flag else "read request", "for address", host_addr)

            if write_flag:
                body_bytes = self.sock.recv(BYTES_PER_BODY)
                while len(body_bytes) < BYTES_PER_BODY:
                    body_bytes += self.sock.recv(BYTES_PER_BODY)
                assert len(body_bytes) == BYTES_PER_BODY, f"read {body_bytes}"
                print("Write request data:", body_bytes)
                output_numpy = np.frombuffer(body_bytes, dtype='>f2')
                self.pinned_mem[host_addr:host_addr+SZ*SZ] = output_numpy
                print(self.pinned_mem)
            else:
                np_dat = self.pinned_mem[host_addr:host_addr+SZ*SZ]
                bytes_dat = np_dat.byteswap().tobytes()
                for i in range(len(bytes_dat)):
                    byte = bytes_dat[i:i+1] # non sliced access isn't what you expect
                    self.sock.sendall(byte)
    # TODO: support tinygrad creating a new device buffer and moving data to pinned_mem (t.to_gpu()). need to lock memory locations to prevent tinygrad and cherry device from reading while someone else is writing?
    # TODO: support tiny grad moving data from pinned_mem to "cpu" land (t.to_cpu())

PinnedDeviceMemorySpace().start()