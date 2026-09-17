`timescale 1ns / 1ps
//
// scrolling_text_engine -- everything about panning text, start to finish:
// pick the string, track the circular window position, slice out 4
// characters, decode them to segments. Merges five pieces that used to be
// separate files (string_rom, pos_max_selector, characters_select,
// position_counter, letter_to_7seg x4); each is still its own
// clearly-labeled section below with the same internal signal names.
//
// Takes string_select from the controller and emits four already-decoded
// active-low seven-segment patterns, left-to-right: seg0 = leftmost
// character currently in the window, seg3 = rightmost.
//
module scrolling_text_engine(
    input  wire       clk,        // 100 MHz board clock
    input  wire       reset,
    input  wire [1:0] string_select,
    input  wire       pan_enable,
    input  wire       pan_load,
    input  wire       pan_clk_level, // panning-rate clock, sampled as a level
    output wire [6:0] seg0, seg1, seg2, seg3
);

    // ---- piece 1: string_rom -- string_select -> 9-char message ----
    // Each string is "word + one trailing blank" so the circular pan
    // reads naturally through a gap before it repeats. Letter codes:
    // BLANK=0, O=1, F=2, A=3, S=4, T=5, D=6, E=7, N=8, R=9.
    reg [35:0] string_bus; // 9 chars x 4 bits, char0 in bits [35:32] ... char8 in bits [3:0]
    localparam BLANK=4'd0, O=4'd1, F=4'd2, A=4'd3, S=4'd4,
               T=4'd5, D=4'd6, E=4'd7, N=4'd8, R=4'd9;
    always @(*) begin
        case (string_select)
            2'b00: string_bus = {O, F, F, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK}; // OFF
            2'b01: string_bus = {S, T, A, R, T, BLANK, BLANK, BLANK, BLANK};          // START_
            2'b10: string_bus = {BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK}; // GAMEPLAY (unused)
            2'b11: string_bus = {D, D, R, BLANK, E, N, D, BLANK, BLANK};              // ddr end_
            default: string_bus = {BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK, BLANK};
        endcase
    end

    // ---- piece 2: pos_max_selector -- string_select -> circular period ----
    // OFF/GAMEPLAY use 9 (full ROM width, so the single-subtraction wrap
    // math below never triggers -- these two are static/unused anyway).
    reg [3:0] wrap_len;
    always @(*) begin
        case (string_select)
            2'b00: wrap_len = 4'd9;
            2'b01: wrap_len = 4'd6;
            2'b10: wrap_len = 4'd9;
            2'b11: wrap_len = 4'd8;
            default: wrap_len = 4'd9;
        endcase
    end

    // ---- piece 3: position_counter -- circular window position ----
    // Single-clock-domain pattern: pan_clk_level arrives as a level and
    // gets edge-detected right here in the 100 MHz domain into a
    // one-cycle pan_tick pulse; the counter itself is clocked by clk.
    wire pan_tick;
    rising_edge_detector pan_tick_det (
        .clk(clk), .reset(reset), .signal(pan_clk_level), .outedge(pan_tick)
    );

    reg [3:0] pos;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pos <= 4'd0;
        end else if (pan_load) begin
            pos <= 4'd0;
        end else if (pan_enable && pan_tick) begin
            if (pos + 4'd1 >= wrap_len) pos <= 4'd0;
            else                        pos <= pos + 4'd1;
        end
    end

    // ---- piece 4: characters_select -- 4-char circular window read ----
    function [3:0] wrap_idx(input [3:0] p, input [3:0] len);
        wrap_idx = (p >= len) ? (p - len) : p;
    endfunction

    wire [3:0] idx0 = pos;
    wire [3:0] idx1 = wrap_idx(pos + 4'd1, wrap_len);
    wire [3:0] idx2 = wrap_idx(pos + 4'd2, wrap_len);
    wire [3:0] idx3 = wrap_idx(pos + 4'd3, wrap_len);

    wire [3:0] char0 = string_bus[(8-idx0)*4 +: 4];
    wire [3:0] char1 = string_bus[(8-idx1)*4 +: 4];
    wire [3:0] char2 = string_bus[(8-idx2)*4 +: 4];
    wire [3:0] char3 = string_bus[(8-idx3)*4 +: 4];

    // ---- piece 5: letter_to_7seg x4 -- decode each character ----
    function [6:0] letter_seg(input [3:0] c);
        case (c)
            BLANK:   letter_seg = 7'b1111111;
            O:       letter_seg = 7'b0000001;
            F:       letter_seg = 7'b0111000;
            A:       letter_seg = 7'b0001000;
            S:       letter_seg = 7'b0100100;
            T:       letter_seg = 7'b1110000;
            D:       letter_seg = 7'b1000010;
            E:       letter_seg = 7'b0110000;
            N:       letter_seg = 7'b1101010;
            R:       letter_seg = 7'b1111010;
            default: letter_seg = 7'b1111111;
        endcase
    endfunction

    assign seg0 = letter_seg(char0);
    assign seg1 = letter_seg(char1);
    assign seg2 = letter_seg(char2);
    assign seg3 = letter_seg(char3);
endmodule
