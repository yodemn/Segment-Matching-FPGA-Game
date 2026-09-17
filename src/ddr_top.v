`timescale 1ns / 1ps
//
// ddr_top -- top level for Dance Dance Revolution (DDR). Instantiates
// exactly two modules, controller and datapath, and wires the named
// control/status signals between them. No behavioral logic here.
//
module ddr_top #(
    parameter PAN_WIDTH     = 25,
    parameter TIMER_WIDTH   = 28,
    parameter REFRESH_WIDTH = 17,
    parameter SPAWN_LIMIT   = 70_000_001,
    parameter TIMER_START   = 12
) (
    input  wire        clk,
    input  wire        R,
    input  wire        P,
    input  wire        S,
    input  wire        SF,
    input  wire        SG,
    input  wire        BTNU, BTND, BTNL, BTNR, BTNC,
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire [15:0] led
);

    wire [1:0] string_select;
    wire [3:0] led_pattern;
    wire       pan_enable, pan_load, board_reset;
    wire       spawn_enable, timer_enable, input_enable;
    wire       c_edge, round_over;

    controller ctrl (
        .clk(clk), .R(R), .P(P),
        .c_edge(c_edge), .round_over(round_over),
        .string_select(string_select), .led_pattern(led_pattern),
        .pan_enable(pan_enable), .pan_load(pan_load), .board_reset(board_reset),
        .spawn_enable(spawn_enable), .timer_enable(timer_enable), .input_enable(input_enable)
    );

    datapath #(
        .PAN_WIDTH(PAN_WIDTH), .TIMER_WIDTH(TIMER_WIDTH),
        .REFRESH_WIDTH(REFRESH_WIDTH), .SPAWN_LIMIT(SPAWN_LIMIT),
        .TIMER_START(TIMER_START)
    ) dp (
        .clk(clk), .R(R), .P(P), .S(S), .SF(SF), .SG(SG),
        .BTNU(BTNU), .BTND(BTND), .BTNL(BTNL), .BTNR(BTNR), .BTNC(BTNC),
        .string_select(string_select), .led_pattern(led_pattern),
        .pan_enable(pan_enable), .pan_load(pan_load), .board_reset(board_reset),
        .spawn_enable(spawn_enable), .timer_enable(timer_enable), .input_enable(input_enable),
        .seg(seg), .an(an), .led(led),
        .c_edge(c_edge), .round_over(round_over)
    );

endmodule
