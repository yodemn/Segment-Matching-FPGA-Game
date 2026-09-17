`timescale 1ns / 1ps
//
// input_mapper -- collects the 5 buttons + 2 switches into the 7-bit
// seg_hit vector the rest of the datapath expects, in {a,b,c,d,e,f,g}
// order. Trivial by itself, but kept as its own module/file to match the
// planned hierarchy 1:1.
//
module input_mapper(
    input  wire BTNU, BTNR, BTNC, BTND, BTNL, SF, SG,
    output wire [6:0] seg_hit
);
    assign seg_hit = {BTNU, BTNR, BTNC, BTND, BTNL, SF, SG};
endmodule
