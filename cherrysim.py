#!/usr/bin/python3
import socket
import sys
import numpy as np
import torch
import atexit
from bitstring import pack, BitArray, ConstBitStream

BYTES_PER_HEADER = 3
BYTES_PER_BODY = 36 # 4*4*18/8

def cherry_float_tile_to_numpy(bytes_dat: bytes) -> np.ndarray:
    assert len(bytes_dat) == BYTES_PER_BODY
    bitstream = ConstBitStream(bytes_dat)
    cherry_float_arr = bitstream.unpack('16*uint:18')
    shift_amt = 32-18
    fp32_arr = [(f << shift_amt).to_bytes(4,byteorder='big') for f in cherry_float_arr] # [fp32.tobytes()+b'\x00' for fp32 in fp32_arr] #tobytes makes it 3 bytes each. then we add extra blank byte
    assert(len(fp32_arr) == 16)
    fp32_bytes = b''.join(fp32_arr)
    output_numpy = np.frombuffer(fp32_bytes, dtype='>f4')
    assert(len(output_numpy == 16))
    return output_numpy

def numpy_to_cherry_float_tile(np_array: np.ndarray) -> bytes:
    assert(len(np_array) == 16)
    bytes_dat = np_array.byteswap().tobytes()
    cherry_floats = []
    for i in range(0, len(bytes_dat), 4):
        fp32 = int.from_bytes(bytes_dat[i:i+4], byteorder='big')
        cherry_floats.append(fp32 >> (32-18))
    assert(len(cherry_floats) == 16)
    # .bytes throws exception if not evenly divisible by 8
    # This exception should never occur since for any SZ==2^n, SZ*SZ*18/8 is an integer
    ret = pack('16*uint:18', *cherry_floats).bytes
    assert len(ret) == BYTES_PER_BODY
    return ret
shouldbe = None
original = None
class PinnedDeviceMemorySpace():
    def __init__(self):
        self.pinned_mem = np.zeros((128,4*4), dtype=np.float32)
        a = 120.0
        for i in range(16, 128, 4):
            a += 1.0
            self.pinned_mem[i] = [a if not i % 16 == 0 else -a] * 4 * 4
        print(numpy_to_cherry_float_tile(self.pinned_mem[20]).hex())
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server_address = ('localhost', 1338)
        self.sock.connect(server_address)
        global shouldbe, original
        shouldbe = torch.tensor(self.pinned_mem).relu().numpy()
        original = self.pinned_mem.copy()
        # sock.close()
    def upload_prog(self, ro_data_addr, instr_start_addr):
        packet_type = 1
        relu_fast_prog_instructions = b'\xf0\x00\x40\x80\x20\x00\x80\x00\x01\x80\x61\x20\xc0\x00'
        packet_length = len(relu_fast_prog_instructions) // 2
        header = (packet_type + (packet_length << 2)).to_bytes(1,'big')
        packet = header + instr_start_addr.to_bytes(2, 'big') + relu_fast_prog_instructions
        self.sock.sendall(packet)

    def start_prog(self, ro_data_addr, instr_start_addr, instr_end_addr):
        packet_type = 2
        header = packet_type.to_bytes(1,'big')
        packet = header + ro_data_addr.to_bytes(1,'big') + instr_start_addr.to_bytes(2,'big') + instr_end_addr.to_bytes(2,'big')
        self.sock.sendall(packet)

    def start(self):
        """
        This causes host computer to listen and
        respond to cisa_mem_* instructions from the cherry device.
        It infinite loops.
        """
        # but first, tell cherry device to start a program
        self.upload_prog(0, 6)
        self.start_prog(0, 6, 13)

        while True:
            header_bytes = self.sock.recv(BYTES_PER_HEADER)
            if len(header_bytes) == 0:
                continue
            while len(header_bytes) < BYTES_PER_HEADER:
                header_bytes += self.sock.recv(BYTES_PER_HEADER-len(header_bytes))
            assert len(header_bytes) == BYTES_PER_HEADER, f"read {header_bytes}"

            # Parse header
            host_addr = int.from_bytes(header_bytes[1:], byteorder='big')
            packet_type = int(header_bytes[0])
            if packet_type == 0:
                assert False # continue
            write_flag = packet_type == 3
            read_flag = packet_type == 2
            prog_end_flag = packet_type == 4
            
            if write_flag or read_flag:
                print("Received", "write request" if write_flag else "read request", "for address", host_addr)

            if write_flag:
                body_bytes = self.sock.recv(BYTES_PER_BODY)
                while len(body_bytes) < BYTES_PER_BODY:
                    body_bytes += self.sock.recv(BYTES_PER_BODY-len(body_bytes))
                assert len(body_bytes) == BYTES_PER_BODY, f"read {body_bytes}"
                print("Write request data:", body_bytes)
                output_numpy = cherry_float_tile_to_numpy(body_bytes)
                self.pinned_mem[host_addr] = output_numpy
                # if host_addr == 20:
                #     return
                print(self.pinned_mem)
            elif read_flag:
                np_dat = self.pinned_mem[host_addr]
                bytes_dat = numpy_to_cherry_float_tile(np_dat)
                print("Read request data:", bytes_dat)
                read_request_response_type = 3
                self.sock.sendall(read_request_response_type.to_bytes(1,'big') + bytes_dat)
            elif prog_end_flag:
                print("PROGRAM COMPLETE")
                exit(0)
    # TODO: support tinygrad creating a new device buffer and moving data to pinned_mem (t.to_gpu()). need to lock memory locations to prevent tinygrad and cherry device from reading while someone else is writing?
    # TODO: support tiny grad moving data from pinned_mem to "cpu" land (t.to_cpu())




mem_space = PinnedDeviceMemorySpace()
@atexit.register
def goodbye():
    print("Success?")
    print((shouldbe == mem_space.pinned_mem).all())
    print(mem_space.pinned_mem[16])
    print(mem_space.pinned_mem[20])
    print(original[16])
    print(original[20])
mem_space.start()