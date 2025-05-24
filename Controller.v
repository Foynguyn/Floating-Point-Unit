module Controller (
    input clk,
    input rst,
    input start,
	 input [3:0] opcode,
    input alu_done,
    output reg start_alu,
	 output reg [1:0] Alu_control,
    output reg done
);

    parameter IDLE = 2'b00;
    parameter CALC = 2'b01;
    parameter DONE = 2'b10;

    reg [1:0] state, next_state;
	 always @(*) begin
		case (opcode)
			4'b0000: Alu_control = 2'b00; // Cộng
			4'b0001: Alu_control = 2'b01; // Trừ
			4'b0010: Alu_control = 2'b10; // Nhân
			4'b0011: Alu_control = 2'b11; // Chia
			default: Alu_control = 2'b00; // Mặc định cộng
		endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE: next_state = start ? CALC : IDLE;
            CALC: next_state = alu_done ? DONE : CALC;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        case (state)
            IDLE:    begin start_alu = start; done = 0; end
            CALC:    begin start_alu = 0; done = 0; end
            DONE:    begin start_alu = 0; done = 1; end
        endcase
    end

endmodule
