// Hardcoded cherry_relu program
module fifo #(parameter fifo_type=0)(
  input clk,
  input reset,
  input re,
  // input we,
  // input [1:0] we_count,
  // input [LINE-1:0] dat_w_1,
  // input [LINE-1:0] dat_w_2,
  // input [LINE-1:0] dat_w_3,
  // input [LINE-1:0] dat_w_4,
  output reg [LINE-1:0] dat_r,
  output full_soon, // at most 4 cycles away from being full
  output empty_soon, // at most 4 cycles away from being empty
  output empty
);
  parameter LINE = (fifo_type == 0) ? 22 : (fifo_type == 1) ? 5 : 17;
  reg [5:0] pos;
  assign empty_soon = pos == 0;
  assign empty = pos >= 18;
  always @(posedge clk) begin
    if (reset) begin
      pos   <= 0;
      dat_r <= 0;
    end else begin
      if (re) begin
        pos <= pos + 1;
        if (fifo_type == 0) begin // dma
          case (pos)
            0: dat_r <= {1'b1, 1'b0, 7'd120, 2'd2, 11'd0}; // active bit. cisa_mem_read with main memory address 120 and the single tile slot and address in that slot (forced 0 for single tile slot)
            1: dat_r <= 22'd0; //empty
            2: dat_r <= 22'd0; //empty
            3: dat_r <= 22'd0; //empty
            4: dat_r <= 22'd0; //empty
            5: dat_r <= 22'd0; //empty
            6: dat_r <= 22'd0; //empty
            7: dat_r <= 22'd0; //empty
            8: dat_r <= 22'd0; //empty
            9: dat_r <= 22'd0; //empty
            10: dat_r <= 22'd0; //empty
            11: dat_r <= 22'd0; //empty
            12: dat_r <= 22'd0; //empty
            13: dat_r <= 22'd0; //empty
            14: dat_r <= 22'd0; //empty
            15: dat_r <= 22'd0; //empty
            16: dat_r <= 22'd0; //empty
            17: dat_r <= {1'b1, 1'b1, 7'd120, 2'd2, 11'd0}; // active bit. cisa_mem_write with main memory address 120 and the single tile slot and address in that slot (forced 0 for single tile slot)
          endcase
        end
        else if (fifo_type == 1) begin // arithmetic
          case (pos)
            0: dat_r <= 5'd0; // empty
            1: dat_r <= 5'd0; // empty
            2: dat_r <= 5'd0; // empty
            3: dat_r <= 5'd0; //empty
            4: dat_r <= 5'd0; //empty
            5: dat_r <= 5'd0; //empty
            6: dat_r <= 5'b10010; // relu active, reg in and reg out both 0
            7: dat_r <= 5'd0; //empty
            8: dat_r <= 5'd0; //empty
            9: dat_r <= 5'd0; //empty
            10: dat_r <= 5'd0; //empty
            11: dat_r <= 5'd0; //empty
            12: dat_r <= 5'd0; //empty
            13: dat_r <= 5'd0; //empty
            14: dat_r <= 5'd0; //empty
            15: dat_r <= 5'd0; //empty
            16: dat_r <= 5'd0; //empty
            17: dat_r <= 5'd0; //empty
          endcase
        end
        else if (fifo_type == 2) begin // cache
          case (pos)
            0: dat_r <= 17'd0; // empty
            1: dat_r <= 17'd0; // empty
            2: dat_r <= 17'd0; // empty
            3: dat_r <= {1'b1, 1'b1, 2'd2, 11'd0, 2'd0}; // cisa_load active. load. single tile slot, address in that slot 0 (forced since only fit one tile), matmul_input register
            4: dat_r <= 17'd0; //empty
            5: dat_r <= 17'd0; //empty
            6: dat_r <= 17'd0; //empty
            7: dat_r <= 17'd0; //empty
            8: dat_r <= 17'd0; //empty
            9: dat_r <= 17'd0; //empty
            10: dat_r <= 17'd0; //empty
            11: dat_r <= 17'd0; //empty
            12: dat_r <= 17'd0; //empty
            13: dat_r <= 17'd0; //empty
            14: dat_r <= {1'b1, 1'b0, 2'd2, 11'd0, 2'd2};//{1'b1, 1'b0, 2'd0, 11'd0, 2'd2}; // cisa_store active. store. private slot. address in that slot. register to store from
            15: dat_r <= 17'd0; //empty
            16: dat_r <= 17'd0; //empty
            17: dat_r <= 17'd0; //empty
          endcase
        end
      end else begin
        dat_r <= 0;
      end
    end
  end
endmodule

module fake_queue(
  input                         reset,
  input                         clk,
  input                         re,
  output dma_instruction        dma_instr,
  output arithmetic_instruction arithmetic_instr,
  output regfile_instruction    cache_instr,
  output wire                   empty
);
fifo #(
.fifo_type(0)
) dma_queue(
  .clk(clk),
  .reset(reset),
  .re(re),
  .dat_r(dma_instr),
  .empty(empty)
);

fifo #(
.fifo_type(1)
) arithmetic_queue(
  .clk(clk),
  .reset(reset),
  .re(re),
  .dat_r(arithmetic_instr)
);

fifo #(
.fifo_type(2)
) cache_queue(
  .clk(clk),
  .reset(reset),
  .re(re),
  .dat_r(cache_instr)
);
endmodule