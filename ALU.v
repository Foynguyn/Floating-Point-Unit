module ALU(
	input clk,
	input start,
	input [1:0] ALU_Control,
	input [31:0] a,
	input [31:0] b,
	output done,
	output [31:0] result_ieee754
);
	
	parameter Add = 2'd0;
	parameter Sub = 2'd1;
	parameter Mul = 2'd2;
	parameter Div = 2'd3;
	
	wire start_add = start && (ALU_Control == Add || ALU_Control == Sub);
	wire start_sub = start && (ALU_Control == Sub);
   wire start_mul = start && (ALU_Control == Mul);
   wire start_div = start && (ALU_Control == Div);
	
	wire [31:0] sum_result, mul_result, div_result;
	wire done_add, done_mul, done_div;
	
	fp_adder_fsm add_sub (
        .clk(clk),
        .start(start_add),
        .a(a),
        .b(b),
        .sub(start_sub),
        .sum(sum_result),
        .done(done_add)
   );

   multiplier mul (
        .clk(clk),
        .start(start_mul),
        .A(a),
        .B(b),
        .product(mul_result),
        .done(done_mul)
   );

   Divider div (
        .clk(clk),
        .start(start_div),
        .a(a),
        .b(b),
        .result(div_result),
        .done(done_div)
   );
	
	assign result_ieee754 = (ALU_Control == Add || ALU_Control == Sub) ? sum_result :
									(ALU_Control == Mul) ? mul_result :
									(ALU_Control == Div) ? div_result : 32'd0;

   assign done =  (ALU_Control == Add || ALU_Control == Sub) ? done_add :
						(ALU_Control == Mul) ? done_mul :
						(ALU_Control == Div) ? done_div : 1'b0;

endmodule

	