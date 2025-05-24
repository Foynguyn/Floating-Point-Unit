module Datapath (
    input clk,
    input start,
    input [1:0] ALU_Control,
    input [31:0] a,
    input [31:0] b,
    output [31:0] result_out,
    output done
);

    wire [31:0] a_encoded, b_encoded, alu_result;
    wire alu_done;

    Encoder encoder_a (.floating_point(a), .ieee754(a_encoded));
    Encoder encoder_b (.floating_point(b), .ieee754(b_encoded));

    ALU alu (
        .clk(clk),
        .start(start),
        .ALU_Control(ALU_Control),
        .a(a_encoded),
        .b(b_encoded),
        .result_ieee754(alu_result),
        .done(alu_done)
    );

    Decoder decoder_out (.fpNumber(alu_result), .fixedPoint(result_out));

    assign done = alu_done;

endmodule
