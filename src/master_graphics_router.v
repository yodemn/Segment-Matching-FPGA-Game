`timescale 1ns / 1ps
//
// master_graphics_router -- decides what actually lands on the physical
// display: board bits, score digits, or scrolling text, per digit, then
// hands the result to the reused Lab 2 anode scanner. Merges the
// digit-select mux logic + digit_to_7seg (x2, for score) + wraps
// time_mux_state_machine.
//
// DONE has two sub-phases that both drive led_pattern=1000 (see
// controller.v); string_select doubles as the discriminator here:
// string_select==11 means "show ddr end text", anything else while
// led_pattern==1000 means "score hold".
//
module master_graphics_router(
    input  wire        refresh_clk_level, // display-refresh clock, already a level
    input  wire [3:0]  led_pattern,
    input  wire [1:0]  string_select,
    input  wire [13:0] board,
    input  wire [6:0]  score,             // 0-99, binary
    input  wire [6:0]  text_seg0, text_seg1, text_seg2, text_seg3, // from scrolling_text_engine
    output wire [6:0]  seg,
    output wire [3:0]  an
);

    // ---- piece 1: display-source mux logic (per digit) ----
    wire is_gameplay   = led_pattern[2]; // 0100
    wire is_done       = led_pattern[3]; // 1000
    wire is_done_text  = is_done && (string_select == 2'b11);
    wire is_done_score = is_done && !is_done_text;

    wire show_score = is_gameplay || is_done_score; // right two digits
    wire show_board = is_gameplay;                   // left two digits = board bits
    wire blank_left = is_done_score;                 // left two digits forced off

    // ---- piece 2: digit_to_7seg x2 -- score tens/ones decode ----
    function [6:0] bcd_seg(input [3:0] d);
        case (d)
            4'd0: bcd_seg = 7'b0000001;
            4'd1: bcd_seg = 7'b1001111;
            4'd2: bcd_seg = 7'b0010010;
            4'd3: bcd_seg = 7'b0000110;
            4'd4: bcd_seg = 7'b1001100;
            4'd5: bcd_seg = 7'b0100100;
            4'd6: bcd_seg = 7'b0100000;
            4'd7: bcd_seg = 7'b0001111;
            4'd8: bcd_seg = 7'b0000000;
            4'd9: bcd_seg = 7'b0000100;
            default: bcd_seg = 7'b1111111;
        endcase
    endfunction

    wire [3:0] score_tens = score / 10;
    wire [3:0] score_ones = score % 10;
    wire [6:0] score_tens_seg = bcd_seg(score_tens);
    wire [6:0] score_ones_seg = bcd_seg(score_ones);

    // ---- final per-digit selection ----
    wire [6:0] digit3 = show_board ? ~board[13:7] : (blank_left ? 7'b1111111 : text_seg0); // leftmost
    wire [6:0] digit2 = show_board ? ~board[6:0]  : (blank_left ? 7'b1111111 : text_seg1);
    wire [6:0] digit1 = show_score ? score_tens_seg : text_seg2;
    wire [6:0] digit0 = show_score ? score_ones_seg : text_seg3; // rightmost

    // ---- piece 3: time_mux_state_machine, reused unchanged from Lab 2 Part 3 ----
    time_mux_state_machine dispmux (
        .clk(refresh_clk_level), .reset(1'b0),
        .in0(digit0), .in1(digit1), .in2(digit2), .in3(digit3),
        .an(an), .sseg(seg)
    );
endmodule
