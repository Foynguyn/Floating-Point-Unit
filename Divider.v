module Divider(
    input [31:0] a, // So bi chia
    input [31:0] b, // So chia
    input clk,
    input start,
    output reg [31:0] result,
	 output reg done
);

reg sign_result;
reg [7:0] exp_result;
reg [23:0] dividend, divisor, quotient;

parameter IDLE = 0, INIT = 1, DIVISION = 2, NORMALIZE = 3, DONE = 4;
reg [2:0] state = 3'd0;

always @(posedge clk) begin
    case (state)
		  IDLE: begin
				done <= 0;
				//result <= 0;
				if (start) state <= INIT;
		  end
        INIT: begin
            sign_result <= a[31] ^ b[31];
				exp_result <= (a[30:23] - b[30:23]) + 8'd127;
					 
            dividend <= {1'b1, a[22:0]};
            divisor <= {1'b1, b[22:0]};
				
				quotient <= 0;
				state <= DIVISION;
				done <= 0;
        end

        DIVISION: begin
            if (dividend >= divisor) begin
                dividend = dividend - divisor;
                quotient = (quotient << 1) | 1'b1;
            end else begin
                quotient = (quotient << 1);
            end
				
				divisor = divisor >> 1;
				
            if (divisor == 0) state <= NORMALIZE;
				else state <= DIVISION;
				
        end

        NORMALIZE: begin
            if (quotient[23] == 0 && exp_result > 0) begin
                quotient = quotient << 1;
                exp_result = exp_result - 8'd1;
            end else begin
                state <= DONE;
            end
        end

        DONE: begin
            if (b == 0) result <= {sign_result, 8'b11111111, 23'b0};
            else result <= {sign_result, exp_result, quotient[22:0]};
            state = IDLE;
				done = 1;
        end
    endcase
end

endmodule
