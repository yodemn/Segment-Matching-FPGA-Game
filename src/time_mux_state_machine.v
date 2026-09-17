`timescale 1ns / 1ps
//
// time_mux_state_machine -- reused UNCHANGED from Lab 2 Part 3, per the
// Lab 4b handout ("time_mux_state_machine -- the four-state time
// multiplexer from Lab 2 Part 3, unchanged").
//
// Convention (matches our earlier Lab 2 usage): in0 -> an[0] (rightmost
// digit), in1 -> an[1], in2 -> an[2], in3 -> an[3] (leftmost digit). In this
// project: in0/in1 = score ones/tens digits, in2/in3 = the two game-board
// digits.
//
// Note: this module is clocked directly by whatever `clk` it's given --
// in the datapath we wire that to a clkdiv LEVEL output (the refresh
// clock), the same "clock derived from a counter" pattern Lab 2 already
// used for this exact module. Lab 4b's single-clock-domain guidance
// (edge-detect a slow level in the 100 MHz domain instead of clocking off
// it directly) is new advice for MODULES WE'RE WRITING THIS LAB
// (position_counter, timer_reg, etc.) -- it doesn't retroactively apply to
// time_mux_state_machine, which the handout explicitly says to reuse
// unchanged.
//
module time_mux_state_machine(
    input  wire        clk,
    input  wire        reset,
    input  wire [6:0]  in0, in1, in2, in3,
    output reg  [3:0]  an,
    output reg  [6:0]  sseg
);
    reg [1:0] state = 2'b00, next_state;

    always @(*) begin
        case (state)
            2'b00: next_state = 2'b01;
            2'b01: next_state = 2'b10;
            2'b10: next_state = 2'b11;
            2'b11: next_state = 2'b00;
            default: next_state = 2'b00;
        endcase
    end

    always @(*) begin
        case (state)
            2'b00: sseg = in0;
            2'b01: sseg = in1;
            2'b10: sseg = in2;
            2'b11: sseg = in3;
            default: sseg = 7'b1111111;
        endcase
    end

    always @(*) begin
        case (state)
            2'b00: an = 4'b1110;
            2'b01: an = 4'b1101;
            2'b10: an = 4'b1011;
            2'b11: an = 4'b0111;
            default: an = 4'b1111;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset == 1)
            state <= 2'b00;
        else
            state <= next_state;
    end
endmodule
