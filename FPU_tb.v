`timescale 1ns/1ps

module FPU_tb;

    reg 				clk;
	 reg				start;
	 reg				rst;
	 reg	[3:0]		opcode;
    reg	[31:0]	A;
	 reg	[31:0]	B;
	 wire	[31:0]	result;
	 wire				done;

    // Instantiate top module
	 FPU uut (
			 .clk(clk),
			 .rst(rst),
			 .start(start),
			 .opcode(opcode),
			 .A_in(A),
			 .B_in(B),
			 .result_out(result),
			 .done(done)
		);
	 
    // File variables
    integer file, i, r;
	 integer countFail = 0, countPass = 0;
    reg [31:0] expected;
	 real float_A;
	 real float_B;
	 real float_expected;

    // Clock generation
    always #5 clk = ~clk;
	 
    initial begin
		clk = 0;
		start = 0;
		opcode = 0;
		A = 0;
		B = 0;
		float_A = 0;
		float_B = 0;
		float_expected = 0;
		i = 0;

		rst = 1;
		@(posedge clk);
		rst = 0;
		
	  file = $fopen("testcase.txt", "r");
	  if (file == 0) begin
			$display("Can't read sample.txt");
			$finish;
	  end
	  
	  while (!$feof(file) && i < 100) begin

			r = $fscanf(file, "%b %h %f %h %f %h %f\n", opcode, A, float_A, B, float_B, expected, float_expected);
			
			@(posedge clk);
			start = 1;
			@(posedge clk);
			start = 0;
			
			wait(done);
			@(posedge clk);
			
			$display("Testcase %0d: %b", i + 1, opcode);
			$display("Number 1: %h(%.4f), Number 2: %h(%.4f)", A, float_A, B, float_B);
			$display("result: %h", result);
			$display("Expected: %h(%.4f)", expected, float_expected);

			if (result !== expected) begin
				countFail= countFail+1;
				$display("--------FAIL--------");
			end

			
			else begin
				countPass= countPass+1;
				$display("--------PASS--------");
			end
			i = i + 1;
	  end

	  $fclose(file);
	  $display("PASS: %d, FAIL: %d", countPass, countFail);
	  $display("TEST HAS DONE");
	  $stop;
 end

endmodule





