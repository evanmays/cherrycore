module testbench;
	reg clk;
  reg [7:0] cnt;

	initial begin
		$display("doing work");
    clk = 0;
    cnt = 0;
	end

  always
    #5 clk = !clk;

  initial begin
    #140
    $finish; // only triggers if we don't find empty flag sooner. this just prevent infinite loop
  end


  reg reset;
  wire [77:0] dma_instr;
  wire arithmetic_instr;
  wire [16:0] cache_instr;
  wire empty;

  fake_queue #(SZ, LOGCNT, BITS) q (
    .reset(reset),
    .clk (clk),
    .dma_instr (dma_instr),
    .arithmetic_instr (arithmetic_instr),
    .cache_instr (cache_instr),
    .empty (empty)
  );

  initial begin
    reset = 1'b1;
    #10
    reset = 1'b0;
  end

  always @(posedge clk) begin
    cnt <= cnt + 1;
    $display("%d %d -- %x %x %x", cnt, empty,
      dma_instr,
      arithmetic_instr,
      cache_instr
    );
    if (empty) begin
      $finish;
    end
  end

endmodule