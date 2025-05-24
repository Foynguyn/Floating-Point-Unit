module Encoder(
	input [31:0] floating_point,
	output reg [31:0] ieee754
);

	reg sign;
	reg [7:0] exp;
	reg [22:0] mantissa;
	
	reg [31:0] shifted;
   reg [4:0] leading_one_pos;
	
	always @(*) begin
		sign = floating_point[31];
		
		shifted = (sign) ? (~floating_point + 1) : floating_point;

		leading_one_pos = (shifted[31] ? 5'd31 :
		                  shifted[30] ? 5'd30 :
		                  shifted[29] ? 5'd29 :
		                  shifted[28] ? 5'd28 :
		                  shifted[27] ? 5'd27 :
		                  shifted[26] ? 5'd26 :
		                  shifted[25] ? 5'd25 :
		                  shifted[24] ? 5'd24 :
		                  shifted[23] ? 5'd23 :
		                  shifted[22] ? 5'd22 :
		                  shifted[21] ? 5'd21 :
		                  shifted[20] ? 5'd20 :
		                  shifted[19] ? 5'd19 :
		                  shifted[18] ? 5'd18 :
		                  shifted[17] ? 5'd17 :
		                  shifted[16] ? 5'd16 :
		                  shifted[15] ? 5'd15 :
		                  shifted[14] ? 5'd14 :
		                  shifted[13] ? 5'd13 :
		                  shifted[12] ? 5'd12 :
		                  shifted[11] ? 5'd11 :
		                  shifted[10] ? 5'd10 :
		                  shifted[9]  ? 5'd9  :
		                  shifted[8]  ? 5'd8  :
		                  shifted[7]  ? 5'd7  :
		                  shifted[6]  ? 5'd6  :
		                  shifted[5]  ? 5'd5  :
		                  shifted[4]  ? 5'd4  :
		                  shifted[3]  ? 5'd3  :
		                  shifted[2]  ? 5'd2  :
		                  shifted[1]  ? 5'd1  : 5'd0);
								
		shifted = shifted << (31 - leading_one_pos);
		mantissa = shifted[30:8];
		exp = 8'd127 + (leading_one_pos - 8'd16);
		ieee754 = {sign, exp, mantissa};
		
	end
endmodule