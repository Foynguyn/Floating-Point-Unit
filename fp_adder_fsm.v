module fp_adder_fsm (
	input  clk, start,
	input  [31:0] a, b,
	input  sub,
	//output reg [31:0] sum,
	output [31:0] sum,

	output reg done
);
localparam 	IDLE       = 3'd0,
			ALIGN      = 3'd2,  		// exp_diff operation + extend + right_shifter
			ADD_SUB    = 3'd3,  		// final_sign + add_sub
			NORMALIZE  = 3'd4,  		// lod_normalization + exp_adjustment 
			ROUND      = 3'd5,  		// round operation
			FINALIZE   = 3'd6;  		// test operation
	
	// State register
		reg [2:0] state;
		
	// Input registers
		reg [31:0] a_reg, b_reg;

	// Intermediate registers for each stage's outputs
	// ************************- IDLE -************************** \\
		reg [1:0] a_is_inf;
		reg [1:0] b_is_inf;
		reg sign_a;
		reg [7:0] exp_a;
		reg [22:0] frac_a;
		reg sign_b;
		reg [7:0] exp_b;
		reg [22:0] frac_b;
		reg [30:0] abs_a;
		reg [30:0] abs_b;
		reg denormal_flag;
		reg single_denormal;
	// ************************- ALIGN -************************* \\
		reg [7:0] exp_l;
		reg exchange;
		reg [23:0] frac_l;
		reg [23:0] frac_s;
		reg [26:0] shifted_frac_l;
		reg [26:0] shifted_frac_s;
		
		wire [26:0] w_shifted_frac_s;
		wire [23:0] w_frac_s;
		wire [7:0] w_exp_l;
		wire [7:0] w_diff;
		wire w_exchange;
		exp_diff a1(w_diff, w_exp_l, w_exchange, a, b);
		extend1bit_small a3(w_frac_s, a[22:0], b[22:0], w_exchange);
		right_shifter a4(w_shifted_frac_s, w_frac_s, w_diff);
	// ************************- ADD_SUB -*********************** \\
		reg f_sign;
		reg [26:0] result;
		reg [27:0] extended_result;
		reg cout;
	// ************************- NORMALIZE -********************* \\
		reg [26:0] normalized_result;
		reg [7:0] adjusted_exp;
	// ************************- ROUND -************************* \\
		reg [26:0] rounded_sum;
	// ************************- FINAL -************************* \\
		reg [31:0] final_sum;
	// ********************************************************** \\
	always @(posedge clk) begin
		case (state)
			IDLE:
			begin	
				done <= 0;
				if (start == 1) begin
					b_reg <= b;
					a_reg <= a;
					sign_a <= a[31]; 
					exp_a <= a[30:23];
					frac_a <= a[22:0];
					abs_a <= a[30:0];
					sign_b <= sub ? ~b[31] : b[31]; 
					exp_b <= b[30:23];
					frac_b <= b[22:0];
					abs_b <= b[30:0];
					final_sum <= 32'b0;
					a_is_inf <= 2'd0;
					b_is_inf <= 2'd0;
					denormal_flag <= 1'b0;
					single_denormal <= 1'b0;
					state <= ALIGN;
				end
			end
					
			ALIGN:
			begin
				if (a_reg == 32'h7F800000) begin
					a_is_inf <= 2'd1;
				end else if (a_reg == 32'hFF800000) begin
					a_is_inf <= 2'd2;
				end
				if (b_reg == 32'h7F800000) begin
					b_is_inf <= 2'd1;
				end else if (b_reg == 32'hFF800000) begin
					b_is_inf <= 2'd2;
				end

				//exp_diff, extend1bit_large, extend1bit_small, right_shifter
				if (abs_a >= abs_b) begin
					exp_l <= exp_a;	
					exchange <= 1'b0;
					shifted_frac_s <= ((exp_b == 8'd0 && frac_b != 23'd0) == 1'b1) ? {1'b0, frac_b, 3'b000} : w_shifted_frac_s;
					shifted_frac_l <= ((exp_a == 8'd0 && frac_a != 23'd0) == 1'b1) ? {1'b0, frac_a, 3'b000} : {1'b1, frac_a, 3'b000};
					//shifted_frac_s <= w_shifted_frac_s;
					//shifted_frac_l <= {1'b1, frac_a, 3'b000};
				end
				else begin
					exp_l <= exp_b;
					exchange <= 1'b1;
					shifted_frac_s <= ((exp_a == 8'd0 && frac_a != 23'd0)) ? {1'b0, frac_a, 3'b000} : w_shifted_frac_s;
					shifted_frac_l <= ((exp_b == 8'd0 && frac_b != 23'd0)) ? {1'b0, frac_b, 3'b000} : {1'b1, frac_b, 3'b000};
					//shifted_frac_s <= w_shifted_frac_s;
					//shifted_frac_l <= {1'b1, frac_b, 3'b000};
					
				end
				if ((exp_b == 8'd0 && frac_b != 23'd0) && (exp_a == 8'd0 && frac_a != 23'd0)) begin
					denormal_flag <= 1'b1;
				end else if ((exp_b == 8'd0 && frac_b != 23'd0) || (exp_a == 8'd0 && frac_a != 23'd0)) begin
					denormal_flag <= 1'b1;
					single_denormal <= 1'b1;
				end
				state <= ADD_SUB;
			end
			
			ADD_SUB:
			begin
				if ((sign_a ^ sign_b) == 0) begin
					cout <= (({1'b0, shifted_frac_l} + {1'b0, shifted_frac_s}) >> 5'd27) & 1'b1;
					result <= shifted_frac_l + shifted_frac_s;
				end
				else begin
					cout <= (({1'b0, shifted_frac_l} - {1'b0, shifted_frac_s}) >> 5'd27) & 1'b1;
					result <= shifted_frac_l - shifted_frac_s;
				end
				f_sign <= (exchange == 0) ? sign_a : sign_b;
				state <= NORMALIZE;
			end
					
			NORMALIZE:
				begin
					if (denormal_flag == 1'b1) begin
						adjusted_exp <= exp_l;
						normalized_result <= (single_denormal == 1'b1) ? shifted_frac_l : result;
					end else begin
						if (cout == 1) begin
							normalized_result <= result >> 1'b1;
						end
						else begin
							// normalized_result assignment reformatted to a single line
							normalized_result <= result << (result[26] ? 5'd0 : result[25] ? 5'd1 : result[24] ? 5'd2 : result[23] ? 5'd3 : result[22] ? 5'd4 : result[21] ? 5'd5 : result[20] ? 5'd6 : result[19] ? 5'd7 : result[18] ? 5'd8 : result[17] ? 5'd9 : result[16] ? 5'd10 : result[15] ? 5'd11 : result[14] ? 5'd12 : result[13] ? 5'd13 : result[12] ? 5'd14 : result[11] ? 5'd15 : result[10] ? 5'd16 : result[9]  ? 5'd17 : result[8]  ? 5'd18 : result[7]  ? 5'd19 : result[6]  ? 5'd20 : result[5]  ? 5'd21 : result[4]  ? 5'd22 : result[3]  ? 5'd23 : result[2]  ? 5'd24 : result[1]  ? 5'd25 : result[0]  ? 5'd26 : 5'd27 );
						end
						// adjusted_exp assignment reformatted to a single line
						adjusted_exp <= (cout == 1) ? (exp_l + 8'd1) : (exp_l - (result[26] ? 5'd0 : result[25] ? 5'd1 : result[24] ? 5'd2 : result[23] ? 5'd3 : result[22] ? 5'd4 : result[21] ? 5'd5 : result[20] ? 5'd6 : result[19] ? 5'd7 : result[18] ? 5'd8 : result[17] ? 5'd9 : result[16] ? 5'd10 : result[15] ? 5'd11 : result[14] ? 5'd12 : result[13] ? 5'd13 : result[12] ? 5'd14 : result[11] ? 5'd15 : result[10] ? 5'd16 : result[9] ? 5'd17 : result[8] ? 5'd18 : result[7] ? 5'd19 : result[6] ? 5'd20 : result[5] ? 5'd21 : result[4] ? 5'd22 : result[3] ? 5'd23 : result[2] ? 5'd24 : result[1] ? 5'd25 : result[0] ? 5'd26 : 5'd27));
					end
					state <= ROUND;
				end
			
			ROUND:
			begin
				rounded_sum = {(normalized_result[2] & (normalized_result[1] | normalized_result[0])) + normalized_result[26:3], {3'b000}};
				state <= FINALIZE;
			end
			
			FINALIZE:
			begin
				if (a_is_inf == 2'd0 && b_is_inf == 2'd0) begin
					final_sum <= {f_sign, adjusted_exp[7:0], rounded_sum[25:3]};
				end

				done <= 1;
				state <= IDLE;
			end
			default:
				state <= IDLE;
		endcase
	end 
	
	assign sum = final_sum; 
endmodule
