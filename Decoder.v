module Decoder (fpNumber, fixedPoint);
    input [31:0] fpNumber;
    output reg [31:0] fixedPoint;
	 
    wire sign;
    wire [7:0] exponent;
    wire [22:0] mantissa;
    reg [38:0] aligned;
    reg signed [8:0] expVal;

    assign sign = fpNumber[31];
    assign exponent = fpNumber[30:23];
    assign mantissa = fpNumber[22:0];

    always @(*) begin
		expVal = exponent - 8'd127;

		aligned = {1'b1, mantissa};

		if (expVal > 0) begin
			 aligned = aligned << expVal;
		end
		else begin
			 aligned = aligned >> (-expVal);
		end

		fixedPoint = aligned[38:7];

		if (sign) begin
			 fixedPoint = -fixedPoint;
	  end
    end
endmodule
