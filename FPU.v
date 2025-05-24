module FPU (
    input clk,
    input rst,
    input start,
    input [3:0] opcode,
    input [31:0] A_in,
    input [31:0] B_in,
    output [31:0] result_out,
    output done
);

    wire start_alu, alu_done;
	 wire [1:0] alu_control;

    Datapath dp (
        .clk(clk),
        .start(start_alu),
        .ALU_Control(alu_control),
        .a(A_in),
        .b(B_in),
        .result_out(result_out),
        .done(alu_done)
    );

    Controller ctrl (
        .clk(clk),
        .rst(rst),
        .start(start),
		  .opcode(opcode),
        .alu_done(alu_done),
		  .Alu_control(alu_control),
        .start_alu(start_alu),
        .done(done)
    );

endmodule
