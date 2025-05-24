module multiplier(clk, start, A, B, product, done);
    input clk;
    input start;
    input [31:0] A;
    input [31:0] B;
    output reg [31:0] product;
    output reg done;

    wire [26:0] X, Y, Z;
    wire [2:0] doneBPR;
    reg enableBPR;
    reg [48:0] sum;

    parameter m = 12;

    wire [13:0] A_hi = {1'b1, A[22:12]};
    wire [13:0] B_hi = {1'b1, B[22:12]};
    wire [13:0] A_lo = {1'b0, A[11:0]};
    wire [13:0] B_lo = {1'b0, B[11:0]};
    wire [13:0] A_sum = A_hi + A_lo;
    wire [13:0] B_sum = B_hi + B_lo;

    // Gọi các module BPR
    BPR bpr1(.A(A_hi), .B(B_hi), .clk(clk), .start(enableBPR), .done(doneBPR[0]), .result(X));
    BPR bpr2(.A(A_lo), .B(B_lo), .clk(clk), .start(enableBPR), .done(doneBPR[1]), .result(Y));
    BPR bpr3(.A(A_sum), .B(B_sum), .clk(clk), .start(enableBPR), .done(doneBPR[2]), .result(Z));

    parameter START = 2'b00, WAITING = 2'b01, DONE = 2'b10;
	 reg [1:0] state = START;

    always @(posedge clk) begin
        case(state)
            START: begin
                if (start) begin					
                    sum <= 49'd0;
                    enableBPR <= 1'b1;
                    state <= WAITING;
                end else begin
                    done <= 1'b0;
                end
            end
            WAITING: begin
                enableBPR <= 0;
                if(doneBPR != 3'b111) begin
                    state <= WAITING;
                end else begin
                    sum <= (X << (m<<1)) + ((Z - X - Y) << m) + Y;
                    state <= DONE;
                end
            end
            DONE: begin
                product[31] <= A[31] ^ B[31];

                if (sum[47]) begin
                    product[22:0] <= sum[46:24];
                    product[30:23] <= A[30:23] + B[30:23] - 8'd126;
                end else begin
                    product[22:0] <= sum[45:23];
                    product[30:23] <= A[30:23] + B[30:23] - 8'd127;
                end

                done <= 1'b1;
                state <= START;
            end
            default: state <= START;
        endcase
    end
endmodule

module BPR(A, B, clk, start, done, result);
    input clk;
    input start;
    input [13:0] A;
    input [13:0] B;
    output reg done = 0;
    output reg [26:0] result;

    reg [26:0] ext_A;
    reg [13:0] ext_B;
    reg [26:0] sum;

    localparam START = 2'b00, CAL = 2'b01, DONE = 2'b10;
	 reg [2:0] state = START;

    reg [3:0] i;

    always @(posedge clk) begin
        case(state)
            START: begin
                if (start) begin
                    ext_A <= A;
                    ext_B <= B;
                    i <= 4'd0;
                    sum <= 27'd0;
                    done <= 1'b0;
						  result <= 27'd0;
                    state <= CAL;
                end else begin
                    done <= 1'b0;
                end
            end
            CAL: begin
                case(i == 4'd0 ? {ext_B[1:0], 1'b0} : {ext_B[(i<<1)+1], ext_B[i<<1], ext_B[(i<<1)-1]})
                    3'b001, 3'b010: sum <= sum + (ext_A << (i<<1));
                    3'b011: sum <= sum + (ext_A << ((i<<1) + 1));
                    3'b100: sum <= sum - (ext_A << ((i<<1) + 1));
                    3'b101, 3'b110: sum <= sum - (ext_A << (i<<1));
                    default: sum <= sum;
                endcase
                if (i< 4'd6) begin
                    i <= i + 4'd1;
						  state <= CAL;
                end else begin
                    state <= DONE;
                end
            end
            DONE: begin
                result <= sum;
                done <= 1'b1;
                state <= START;
            end
        endcase
    end
endmodule

