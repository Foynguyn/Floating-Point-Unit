
module swap_comparator(
    output exchange,
    output [31:0] fp_large,
    output [31:0] fp_small,
    input [31:0] a,
    input [31:0] b
);
    assign exchange = ({1'b0, b[30:0]} > {1'b0, a[30:0]});
    assign fp_large = exchange ? b : a;
    assign fp_small = exchange ? a : b;
endmodule

module exp_diff(
    output [7:0] diff,
	 output [7:0] exp,
	 output exchange,
	 input [31:0] a,
	 input [31:0] b
); 
	 wire [7:0] exp_large;
	 wire [7:0] exp_small; 
    assign exchange = ({1'b0, b[30:0]} > {1'b0, a[30:0]});
    assign exp_large = exchange ? b[30:23] : a[30:23];
    assign exp_small = exchange ? a[30:23] : b[30:23];
	 assign exp = exp_large;
	 assign diff = exp_large - exp_small;
endmodule

module extend1bit_large(
    output [23:0] num1,
    input [22:0] fraction1,
    input [22:0] fraction2,
    input choose
);
    assign num1 = choose ? {1'b1, fraction2} : {1'b1, fraction1};
endmodule

module extend1bit_small(
    output [23:0] num1,
    input [22:0] fraction1,
    input [22:0] fraction2,
    input choose
);
    assign num1 = choose ? {1'b1, fraction1} : {1'b1, fraction2};
endmodule

module right_shifter (
    // Output: { shifted_mantissa[23:0], Guard, Round, Sticky }
    output wire [26:0] out,
    // Input Mantissa (including hidden '1')
    input wire [23:0] in,
    // Shift amount from Exponent Difference
    // Using 8 bits allows shifts up to 255, which is more than enough
    input wire [7:0]  shift

);

    // --- Parameters ---
    // Width needed for the main part of the mantissa after shifting
    localparam MANTISSA_WIDTH = 24;
    // Extra bits needed: 1 for Guard, 1 for Round, 1+ for Sticky calculation.
    // Having enough extra bits simplifies sticky calculation. Let's use a generous amount
    // to capture bits even for larger shifts. Max realistic shift affecting GRS is ~ MANTISSA_WIDTH + 2.
    // Let's use 30 extra bits to be safe and simplify logic.
    localparam EXTRA_BITS = 30;
    // Total width for the intermediate shift operation
    localparam WIDE_WIDTH = MANTISSA_WIDTH + EXTRA_BITS; // 24 + 30 = 54

    // --- Internal Wires ---
    // Wire holding the input mantissa padded with zeros on the right
    wire [WIDE_WIDTH-1:0] extended_in;
    // Wire holding the result after shifting the extended input
    wire [WIDE_WIDTH-1:0] shifted_extended;

    // --- Logic ---

    // 1. Extend the input mantissa by padding with zeros on the right.
    //    This ensures that bits shifted out are captured in the lower part.
    assign extended_in = {in, {EXTRA_BITS{1'b0}}};

    // 2. Perform the right shift on the extended wire.
    //    Verilog's '>>' performs a logical right shift, filling with zeros from the left, which is appropriate here.
    assign shifted_extended = extended_in >> shift;

    // 3. Extract the required components from the shifted result:

    //    a) The main 24 bits of the shifted mantissa. These are the highest bits after shifting.
    //       They occupy bits [WIDE_WIDTH-1 : EXTRA_BITS] of shifted_extended.
    wire [MANTISSA_WIDTH-1:0] main_shifted = shifted_extended[WIDE_WIDTH-1 : EXTRA_BITS];

    //    b) The Guard bit (G). This is the first bit shifted out, located just below the main mantissa part.
    //       It's at index EXTRA_BITS - 1.
    wire guard_bit = shifted_extended[EXTRA_BITS - 1];

    //    c) The Round bit (R). This is the second bit shifted out.
    //       It's at index EXTRA_BITS - 2.
    wire round_bit = (EXTRA_BITS >= 2) ? shifted_extended[EXTRA_BITS - 2] : 1'b0; // Check if EXTRA_BITS is large enough

    //    d) The Sticky bit (S). This is the logical OR of all bits shifted out after the Round bit.
    //       These are bits from index EXTRA_BITS - 3 down to 0.
    //       The OR-reduction operator '|' is perfect for this.
    wire sticky_bit = (EXTRA_BITS >= 3) ? (|shifted_extended[EXTRA_BITS - 3 : 0]) : 1'b0; // Check if EXTRA_BITS is large enough

    // 4. Combine the components into the 27-bit output vector.
    //    Format: { main_shifted[23:0], G, R, S }
    assign out = {main_shifted, guard_bit, round_bit, sticky_bit};

endmodule

module final_sign (
	output 	add_sub,
	output 	final_sign,
	input 	sign_a,
	input 	sign_b,
	input 	exchange
);

	assign add_sub = sign_a ^ sign_b;
	
	assign final_sign = (exchange == 0) ? sign_a : sign_b;

endmodule

module add_sub(
	output [26:0] 	out,
	output 			cout,
	input [23:0] 	a,
	input [26:0] 	b,
	input 			add_sub
);
	wire op = add_sub;
	wire [27:0] extended_out;
	wire [26:0] extended_a;
	assign extended_a = {a[23:0], 3'b000};

	assign extended_out = (op == 0) ? extended_a + b : extended_a - b; 
	assign cout = extended_out[27];
	assign out = extended_out[26:0];

endmodule

module lod_normalization(
    output [26:0] shifted_sum,
    output [4:0]  norm_shift,  
    output        is_zero,     
    input [26:0]  sum,
    input         cout         
);
    // **Case 1: Overflow (11.xxxx) → Right-shift by 1**
    wire [26:0] overflow_shifted = sum >> cout;

    // **Case 2: No overflow → Left-shift to normalize**
    wire [4:0] leading_one_pos;
    
    assign leading_one_pos = 
        sum[26] ? 5'd0  :  
        sum[25] ? 5'd1  :  
        sum[24] ? 5'd2  :
        sum[23] ? 5'd3  :
        sum[22] ? 5'd4  :
        sum[21] ? 5'd5  :
        sum[20] ? 5'd6  :
        sum[19] ? 5'd7  :
        sum[18] ? 5'd8  :
        sum[17] ? 5'd9  :
        sum[16] ? 5'd10 :
        sum[15] ? 5'd11 :
        sum[14] ? 5'd12 :
        sum[13] ? 5'd13 :
        sum[12] ? 5'd14 :
        sum[11] ? 5'd15 :
        sum[10] ? 5'd16 :
        sum[9]  ? 5'd17 :
        sum[8]  ? 5'd18 :
        sum[7]  ? 5'd19 :
        sum[6]  ? 5'd20 :
        sum[5]  ? 5'd21 :
        sum[4]  ? 5'd22 :
        sum[3]  ? 5'd23 :
        sum[2]  ? 5'd24 :
        sum[1]  ? 5'd25 :
        sum[0]  ? 5'd26 :  
        5'd27;             

    // **Check if sum is zero (subnormal number case)**
    assign is_zero = (sum == 27'b0);

    // **Left-shifted result (normalization)**
    wire [26:0] normalized_sum = sum << leading_one_pos;

    // **Final shift selection (overflow vs. normal case)**
    assign shifted_sum = cout ? overflow_shifted : normalized_sum;
    assign norm_shift  = cout ? 5'd1 : leading_one_pos;

endmodule

module exp_adjustment(
    output [7:0] final_exp,
    input [7:0] exp,         
    input [4:0] shift_amount,  
    input cout                
);
    /* 
		* Exponent adjustment rules:
		* 1. If cout=1 (overflow), right-shifted mantissa by 1 → exp + 1
		* 2. Else, left-shifted by shift_amount → exp - shift_amount
    */
    wire [7:0] adjusted_exp;

    assign adjusted_exp = (cout == 1) ? (exp + 8'd1) : (exp - shift_amount);

    assign final_exp = adjusted_exp;
endmodule

module test(
	output [31:0] rs,
	input sign,
	input [7:0] exp,
	input [26:0] sum
);
	assign rs = {sign, exp[7:0], sum[25:3]};
endmodule


module round(
    output [26:0] rounded_sum,  
    input [26:0] sum            
);
    wire G = sum[2];
    wire R = sum[1];
    wire S = sum[0];

    wire [23:0] significand = sum[26:3];

    wire round_up = G & (R | S);

    wire [23:0] rounded_sig = significand + round_up;

    wire overflow = rounded_sig[23];

    wire [23:0] normalized_sig = overflow ? {1'b1, rounded_sig[22:0]} : rounded_sig;
    assign rounded_sum = {normalized_sig, 3'b000};
endmodule






