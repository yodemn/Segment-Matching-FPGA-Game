`timescale 1ns / 1ps
//
// clkdiv -- parameterized clock divider.
// Fix vs. the version we had from earlier labs: WIDTH is now a parameter
// instead of a hardcoded 2-bit counter, so the same module can be
// instantiated for the ~2-4 Hz pan tick, the ~500 Hz-1 kHz display refresh,
// and (via a smaller override) simulation-friendly fast versions of both --
// exactly what Lab 4a/4b ask for ("ask AI to make your slow_clk module
// parameterized with a WIDTH parameter").
//
// clk_out is a divided-down LEVEL (square wave), not a pulse -- consistent
// with how position_counter (and everything else that consumes a slow
// clock in this design) expects to receive it: as a level to be
// edge-detected in the 100 MHz domain, not as a clock in its own right.
//
module clkdiv #(
    parameter WIDTH = 25   // clk_out period = 2^WIDTH cycles of clk
) (
    input  wire clk,
    input  wire reset,
    output wire clk_out
);
    reg [WIDTH-1:0] count = {WIDTH{1'b0}};

    assign clk_out = count[WIDTH-1];

    always @(posedge clk) begin
        if (reset) count <= {WIDTH{1'b0}};
        else       count <= count + 1'b1;
    end
endmodule
