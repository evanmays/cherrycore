// About 11% LUT usage.
// 2 write ports, 2 read ports
// Needs one clock edge to commit the data.
// Each port can access a specific register for a specific thread
module regfile(
  input clk,
  input reset,
  input freeze,
  input logic port_c_we, port_d_we,
  input [0:LOG_REG_CNT*SUPERSCALAR_WIDTH-1] port_a_read_addr, port_b_read_addr, port_c_write_addr, port_d_write_addr,
  input [REG_WIDTH-1:0] port_c_in, port_d_in,
  output reg [REG_WIDTH-1:0] port_a_out, port_b_out // can probably save power by adding a port_a_re and port_b_re?
);
parameter LOG_REG_CNT = 2;
localparam REG_CNT = (1 << LOG_REG_CNT);
parameter SUPERSCALAR_WIDTH = 4;
parameter REG_WIDTH = 288; // 4x4 18 bit matrix
reg [REG_WIDTH-1:0] mem [0:REG_CNT*SUPERSCALAR_WIDTH-1];
always @(posedge clk) begin
  if (!freeze) begin
    if (port_c_we) begin
      mem[port_c_write_addr] <= port_c_in;
    end
    if (port_d_we) begin
      mem[port_d_write_addr] <= port_d_in;
    end
    port_a_out <= mem[port_a_read_addr];
    port_b_out <= mem[port_b_read_addr];
  end
end
endmodule


// IDK hardly works, basically is doubling the clock
// module regfile(
//   input clk,
//   input port_c_we, port_d_we,
//   input [0:REG_CNT*SUPERSCALAR_WIDTH-1] port_a_read_addr, port_b_read_addr, port_c_write_addr, port_d_write_addr,
//   input [REG_WIDTH-1:0] port_c_in, port_d_in,
//   output reg [REG_WIDTH-1:0] port_a_out, port_b_out
// );
// parameter REG_CNT = 4;
// parameter SUPERSCALAR_WIDTH = 4;
// parameter REG_WIDTH = 18;//288; // 4x4 18 bit matrix
// reg [REG_WIDTH-1:0] mem [0:REG_CNT*SUPERSCALAR_WIDTH-1];

// always @(posedge clk) begin
//   if (port_c_we) begin
//     mem[port_c_write_addr] <= port_c_in;
//   end
//   port_a_out <= mem[port_a_read_addr];
// end
// always @(negedge clk) begin
//   if (port_d_we) begin
//     mem[port_d_write_addr] <= port_d_in;
//   end
//   port_b_out <= mem[port_b_read_addr];
// end
// endmodule