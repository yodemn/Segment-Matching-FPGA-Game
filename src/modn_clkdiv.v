`timescale 1ns / 1ps
//
// modn_clkdiv -- free-running divide-by-LIMIT pulse generator.
//
// WHY THIS EXISTS SEPARATELY FROM clkdiv: our Lab 4a spec requires the
// spawn-tick period (in 100 MHz cycles) to be ODD and NOT a multiple of 7,
// so that digit_toggle (period 2) and seg_rot (period 7) get sampled at a
// walking phase instead of freezing on one digit/segment forever. A plain
// binary clkdiv's period is always 2^WIDTH -- always even -- which would
// violate that constraint outright. This module counts 0..LIMIT-1 and
// pulses `tick` for one cycle when it wraps, so LIMIT can be any integer,
// not just a power of two.
//
// Unlike clkdiv (which outputs a LEVEL), this outputs a one-cycle PULSE
// directly, since segment_board's spawn_tick port expects a pulse, not a
// level to be edge-detected.
//
module modn_clkdiv #(
    parameter LIMIT = 35_000_001   // ~350 ms at 100 MHz; odd, not a multiple of 7
) (
    input  wire clk,
    input  wire reset,
    output wire tick
);
    localparam CW = $clog2(LIMIT);
    reg [CW-1:0] count;

    assign tick = (count == LIMIT-1);

    always @(posedge clk) begin
        if (reset || count == LIMIT-1) count <= {CW{1'b0}};
        else                            count <= count + 1'b1;
    end
endmodule
