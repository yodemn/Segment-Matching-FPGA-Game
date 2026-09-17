`timescale 1ns / 1ps
//
// hit_miss_math -- decides which presses are hits vs. misses against the
// current board, and keeps score. Merges comparator_array + score_reg.
//
module hit_miss_math(
    input  wire        clk,
    input  wire        reset,
    input  wire        board_reset,
    input  wire [13:0] board,
    input  wire        S,
    input  wire [6:0]  seg_hit,
    input  wire        input_enable,
    output wire [6:0]  correct,
    output wire [6:0]  flash_seg,
    output reg  [6:0]  score   // 0-99, binary
);

    // ---- piece 1: comparator_array -- 7 parallel compare units, no priority ----
    wire [6:0] board_half = S ? board[13:7] : board[6:0];
    assign correct   = input_enable ? (seg_hit &  board_half) : 7'b0;
    assign flash_seg = input_enable ? (seg_hit & ~board_half) : 7'b0; // display-only, combinational

    wire [2:0] hit_count = correct[0] + correct[1] + correct[2] + correct[3] +
                            correct[4] + correct[5] + correct[6]; // popcount, 0-7

    // ---- piece 2: score_reg -- saturating accumulator ----
    wire [7:0] sum = {1'b0, score} + {5'b0, hit_count};

    always @(posedge clk or posedge reset) begin
        if (reset || board_reset) score <= 7'd0;
        else if (hit_count != 3'd0) score <= (sum > 8'd99) ? 7'd99 : sum[6:0];
    end
endmodule
