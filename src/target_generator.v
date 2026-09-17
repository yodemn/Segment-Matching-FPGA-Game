`timescale 1ns / 1ps
//
// target_generator -- owns everything about WHERE segments spawn and
// WHAT's currently lit on the game board. Merges three pieces that used
// to be separate files (digit_toggle, seg_rot, segment_board) into one
// module; each piece is still its own clearly-labeled section below with
// the same internal signal names they had as standalone files, so the
// data flow reads the same as before, just without the file boundaries.
//
module target_generator(
    input  wire        clk,
    input  wire        reset,
    input  wire        board_reset,
    input  wire        spawn_enable,
    input  wire        spawn_tick,
    input  wire        input_enable,
    input  wire        S,
    input  wire [6:0]  correct,   // per-segment correct-hit pulses from hit_miss_math
    output reg  [13:0] board
);

    // ---- piece 1: digit_toggle -- 1-bit free-running, period 2 @ clk ----
    // Selects which of the 2 board digits a new spawn lands on. Never
    // gated, runs continuously.
    reg digit_idx;
    always @(posedge clk or posedge reset) begin
        if (reset) digit_idx <= 1'b0;
        else       digit_idx <= ~digit_idx;
    end

    // ---- piece 2: seg_rot -- 7-bit one-hot rotate, period 7 @ clk ----
    // Selects which segment (a-g) a new spawn lands on. Also free-running.
    reg [6:0] seg_idx;
    always @(posedge clk or posedge reset) begin
        if (reset) seg_idx <= 7'b0000001;
        else       seg_idx <= {seg_idx[5:0], seg_idx[6]}; // rotate left
    end

    // ---- piece 3: segment_board -- 14-bit individually set/clear array ----
    // bits [6:0] = digit S=0's segments, bits [13:7] = digit S=1's segments.
    wire [13:0] set_mask   = (spawn_enable && spawn_tick) ? (digit_idx ? {seg_idx, 7'b0} : {7'b0, seg_idx}) : 14'b0;
    wire [13:0] clear_mask = input_enable ? (S ? {correct, 7'b0} : {7'b0, correct}) : 14'b0;
    wire [13:0] next_board = (board & ~clear_mask) | set_mask;

    always @(posedge clk or posedge reset) begin
        if (reset || board_reset) board <= 14'b0;
        else                       board <= next_board;
    end
endmodule
