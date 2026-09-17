`timescale 1ns / 1ps
//
// game_timer -- counts down from TIMER_START on each timer_tick while
// timer_enable is high, floors at 0. Drives the 12-LED countdown bar.
// (Renamed from timer_reg -- this was already close to 1:1 with the
// planned hierarchy, no real merging needed.)
//
module game_timer #(
    parameter TIMER_START = 12   // must be <= 12 to fit the LED bar 1:1
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        board_reset,
    input  wire        timer_enable,
    input  wire        timer_tick,
    output reg  [3:0]  timer_count,
    output wire [11:0] timer_led
);
    assign timer_led = 12'hFFF >> (12 - timer_count);

    always @(posedge clk or posedge reset) begin
        if (reset || board_reset) timer_count <= TIMER_START[3:0];
        else if (timer_enable && timer_tick && timer_count != 4'd0)
            timer_count <= timer_count - 4'd1;
    end
endmodule
