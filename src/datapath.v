`timescale 1ns / 1ps
//
// datapath -- wires the six top-level datapath blocks (input_mapper,
// target_generator, hit_miss_math, game_timer, scrolling_text_engine,
// master_graphics_router) plus the four clock dividers and BTNC's edge
// detector together. No behavioral logic of its own beyond round_over
// (a simple 3-way OR that doesn't belong inside any single block) and
// the LED output mux.
//
// All four clock-divider widths/limits are parameters so the integration
// testbench can override them to simulation-friendly values. Defaults
// below are hardware values.
//
module datapath #(
    parameter PAN_WIDTH     = 25,          // ~3 Hz pan tick
    parameter TIMER_WIDTH   = 28,          // ~0.37 Hz timer tick (~2.7 s/tick, ~32 s round)
    parameter REFRESH_WIDTH = 17,          // ~763 Hz display refresh
    parameter SPAWN_LIMIT   = 70_000_001,  // ~700 ms spawn tick; odd, not a multiple of 7
    parameter TIMER_START   = 12           // matches the 12-LED timer bar
) (
    input  wire        clk,
    input  wire        R,
    input  wire        P,
    input  wire        S,
    input  wire        SF,
    input  wire        SG,
    input  wire        BTNU, BTND, BTNL, BTNR, BTNC,

    // control signals from controller
    input  wire [1:0]  string_select,
    input  wire [3:0]  led_pattern,
    input  wire        pan_enable,
    input  wire        pan_load,
    input  wire        board_reset,
    input  wire        spawn_enable,
    input  wire        timer_enable,
    input  wire        input_enable,

    // physical outputs
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire [15:0] led,

    // status to controller
    output wire        c_edge,
    output wire        round_over
);

    // ---------------------------------------------------------------
    // BTNC edge detection (status to controller)
    // ---------------------------------------------------------------
    rising_edge_detector btnc_edge_det (
        .clk(clk), .reset(R), .signal(BTNC), .outedge(c_edge)
    );

    // ---------------------------------------------------------------
    // Clock dividers
    // ---------------------------------------------------------------
    wire pan_clk_level, timer_clk_level, refresh_clk_level;

    clkdiv #(.WIDTH(PAN_WIDTH))     pan_div     (.clk(clk), .reset(R), .clk_out(pan_clk_level));
    clkdiv #(.WIDTH(TIMER_WIDTH))   timer_div   (.clk(clk), .reset(R), .clk_out(timer_clk_level));
    clkdiv #(.WIDTH(REFRESH_WIDTH)) refresh_div (.clk(clk), .reset(1'b0), .clk_out(refresh_clk_level));

    wire timer_tick;
    rising_edge_detector timer_tick_det (
        .clk(clk), .reset(R), .signal(timer_clk_level), .outedge(timer_tick)
    );

    wire spawn_tick;
    modn_clkdiv #(.LIMIT(SPAWN_LIMIT)) spawn_div (.clk(clk), .reset(R), .tick(spawn_tick));

    // ---------------------------------------------------------------
    // The six datapath blocks
    // ---------------------------------------------------------------
    wire [6:0] seg_hit;
    input_mapper imap (
        .BTNU(BTNU), .BTNR(BTNR), .BTNC(BTNC), .BTND(BTND), .BTNL(BTNL), .SF(SF), .SG(SG),
        .seg_hit(seg_hit)
    );

    wire [13:0] board;
    wire [6:0]  correct, flash_seg;
    target_generator tgen (
        .clk(clk), .reset(R), .board_reset(board_reset),
        .spawn_enable(spawn_enable), .spawn_tick(spawn_tick),
        .input_enable(input_enable), .S(S), .correct(correct),
        .board(board)
    );

    wire [6:0] score;
    hit_miss_math hmm (
        .clk(clk), .reset(R), .board_reset(board_reset),
        .board(board), .S(S), .seg_hit(seg_hit), .input_enable(input_enable),
        .correct(correct), .flash_seg(flash_seg), .score(score)
    );

    wire [3:0]  timer_count;
    wire [11:0] timer_led_bar;
    game_timer #(.TIMER_START(TIMER_START)) gtimer (
        .clk(clk), .reset(R), .board_reset(board_reset),
        .timer_enable(timer_enable), .timer_tick(timer_tick),
        .timer_count(timer_count), .timer_led(timer_led_bar)
    );

    assign round_over = (timer_count == 4'd0) || (score >= 7'd99) || (&board);

    wire [6:0] text_seg0, text_seg1, text_seg2, text_seg3;
    scrolling_text_engine stext (
        .clk(clk), .reset(R), .string_select(string_select),
        .pan_enable(pan_enable), .pan_load(pan_load), .pan_clk_level(pan_clk_level),
        .seg0(text_seg0), .seg1(text_seg1), .seg2(text_seg2), .seg3(text_seg3)
    );

    master_graphics_router mgr (
        .refresh_clk_level(refresh_clk_level),
        .led_pattern(led_pattern), .string_select(string_select),
        .board(board), .score(score),
        .text_seg0(text_seg0), .text_seg1(text_seg1), .text_seg2(text_seg2), .text_seg3(text_seg3),
        .seg(seg), .an(an)
    );

    // ---------------------------------------------------------------
    // LEDs: mode indicator passthrough + timer bar (shown only in GAMEPLAY)
    // ---------------------------------------------------------------
    wire is_gameplay = led_pattern[2];
    assign led = {(is_gameplay ? timer_led_bar : 12'b0), led_pattern};

endmodule
