// RISK extensions
// 4x4 registers
// we have 270 18-bit rams, need this instead of 19. depth is 1024
// let's make 128 BRAMs, that's 256 elements of read bandwidth
// 2304-bit wide databus if we only use one port (36864-bit in big chip)
// this is also the size of ECC
// use a 9 bit mantissa (cherryfloat)

module single_dcache_mem #(parameter LINE=18) (
  input clk,
  input [9:0] addr,
  output reg [LINE-1:0] data_r,
  input [LINE-1:0] data_w,
  input we
);
  reg [LINE-1:0] mem [0:1023];
  always @(posedge clk) begin
    if (we) begin
      mem[addr] <= data_w;
    end else begin
      data_r <= mem[addr];
    end
  end
endmodule


// this is hard to synthesize
module dcache_mem_high_priority #(parameter SZ=4, LOGCNT=5, BITS=18) (
  input clk,
  input [10+LOGCNT-1:0] addr,
  input [10+LOGCNT-2:0] stride_x,
  input [10+LOGCNT-2:0] stride_y,
  input [BITS*SZ*SZ-1:0] dat_w,
  input we,
  output reg [BITS*SZ*SZ-1:0] dat_r,
  output wire stall
);
  parameter CNT=(1<<LOGCNT);

  // strides
  //parameter SZ_X=SZ;
  //parameter LINE=BITS;

  // strideless
  parameter SZ_X=1;
  parameter LINE=BITS*SZ;

  // 1 cycle to get all the addresses
  reg [(10+LOGCNT)*SZ*SZ_X-1:0] addrs;
  reg [SZ*SZ_X-1:0] complete_flags; // set to 0 when we have completed the memory request for the address. May be delayed due to bank conflicts
  assign stall = !(&complete_flags);

  generate
    genvar x,y;
    for (y=0; y<SZ; y=y+1) begin
      for (x=0; x<SZ_X; x=x+1) begin
        always @(posedge clk) begin
          if (!stall) begin
            addrs[(y*SZ_X+x)*(10+LOGCNT) +: (10+LOGCNT)] <= addr + stride_x*x + stride_y*y;  
          end
        end
      end
    end
  endgenerate
  
  reg [CNT*SZ_X*SZ-1:0] mask, mask_intermediary;
  wire [LINE*CNT-1:0] outs;

  generate
    genvar i,k;

    // CNT number of priority encoders of SZ*SZ
    for (i=0; i<CNT; i=i+1) begin
      reg [9:0] taddr;
      reg [LINE-1:0] in;
      wire [LINE-1:0] out;
      single_dcache_mem #(LINE) rsm(
        .clk(clk),
        .addr(taddr),
        .data_r(out),
        .data_w(in),
        .we(we)
      );

      integer l;
      always @(posedge clk) begin
        //ens[i] <= 'b0;
        mask[i*SZ_X*SZ +: SZ_X*SZ] <= 'b0;
        for (l=SZ_X*SZ-1; l>=0; l=l-1) begin
          if (addrs[(10+LOGCNT)*l +: LOGCNT] == i && complete_flags[l] == 0) begin
            mask_intermediary[i*SZ_X*SZ +: SZ_X*SZ] = (1 << l);
            mask[i*SZ_X*SZ +: SZ_X*SZ] <= mask_intermediary[i*SZ_X*SZ +: SZ_X*SZ];
            taddr <= addrs[(10+LOGCNT)*l+LOGCNT +: 10];
            in <= dat_w[LINE*l +: LINE];
          end
        end
        complete_flags <= stall ? (complete_flags | complete_flags_intermediary) : 0;
      end
      assign outs[i*LINE +: LINE] = out;
    end

    wire [CNT*SZ_X*SZ-1:0] rotated_mask;
    wire [SZ*SZ_X-1:0] complete_flags_intermediary;
    for (k=0; k<SZ_X*SZ; k=k+1) begin
        for (i=0; i<CNT; i=i+1) begin
          assign rotated_mask[k*CNT + i] = mask_intermediary[i*SZ_X*SZ + k];
          assign complete_flags_intermediary[k] = |rotated_mask[CNT*k +: CNT];
        end
    end

    // this is SZ*SZ number of CNT to 1 muxes. these don't have to be priority encoders, really just a big or gate
    for (k=0; k<SZ_X*SZ; k=k+1) begin
      wire [CNT-1:0] lmask;
      for (i=0; i < CNT; i=i+1) assign lmask[i] = mask[i*SZ_X*SZ + k];

      // https://andy-knowles.github.io/one-hot-mux/
      // in this chip, this is 16 registers x 32 BRAMs x 18-bits
      // in final edition, this will be 1024 registers x 2048 BRAMs x 19-bits
      integer l;
      always @(posedge clk) begin
        if (lmask != 'b0) begin
          dat_r[LINE*k +: LINE] = 'b0;
          for (l=0; l<CNT; l=l+1)
            dat_r[LINE*k +: LINE] = dat_r[LINE*k +: LINE] | (outs[LINE*l +: LINE] & {LINE{lmask[l]}});
        end
      end
    end

  endgenerate

endmodule

// Simple memory, one read port, one write port.
module dcache_mem_low_priority #(parameter SZ=4, LOGCNT=5, BITS=18) (
  input clk,
  input [10+LOGCNT-1:0] addr,
  input [LINE-1:0] dat_w,
  input we,
  output reg [LINE-1:0] dat_r
);
  parameter CNT=(1<<LOGCNT);
  parameter LINE=BITS*SZ*SZ;

  reg [LINE-1:0] mem [0:CNT*1024-1];
  always @(posedge clk) begin
    if (we) begin
      mem[addr] <= dat_w;
    end else begin
      dat_r <= mem[addr];
    end
  end

endmodule
