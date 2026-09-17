`timescale 1ns / 1ps
//
// Unit testbench for scrolling_text_engine -- replaces the old separate
// tb_letter_to_7seg and tb_position_counter now that both are internal
// pieces of this merged module rather than standalone files. Covers both
// halves: the letter-decode table (every code produces the right active-low
// pattern) and the circular-wraparound position behavior (walks a full
// lap of "START_" and checks the exact letter sequence it produces).
//
// AI PROMPT USED (paraphrased): "Write a self-checking testbench for this
// merged scrolling_text_engine module. Since letter_to_7seg and
// position_counter no longer exist as separate modules, test their
// behavior through this module's ports instead: force string_select=01
// (START) and step pan_clk_level through a full circular lap, checking
// the exact 4-character window sequence at each step against the known
// STAR/TART/ART_/RT_S/T_ST/_STA loop."
// Reviewed by hand: added the explicit expected-sequence table rather
// than just checking segments change, since a change-only check wouldn't
// catch a wraparound bug that still produces *some* different-looking
// output, just the wrong one (exactly the OOFF-style bug found earlier
// in this project).
//
module tb_scrolling_text_engine;
    reg clk = 0, reset = 1, pan_enable = 0, pan_load = 0, pan_clk_level = 0;
    reg [1:0] string_select = 2'b11; // deliberately wrong; set to START explicitly below to force a real transition
    wire [6:0] seg0, seg1, seg2, seg3;
    integer errors = 0;

    scrolling_text_engine uut (
        .clk(clk), .reset(reset), .string_select(string_select),
        .pan_enable(pan_enable), .pan_load(pan_load), .pan_clk_level(pan_clk_level),
        .seg0(seg0), .seg1(seg1), .seg2(seg2), .seg3(seg3)
    );

    always #5 clk = ~clk;

    // One expected pattern per letter, active-low, {a,b,c,d,e,f,g}.
    localparam BLANK_P = 7'b1111111;
    localparam S_P     = 7'b0100100;
    localparam T_P     = 7'b1110000;
    localparam A_P     = 7'b0001000;
    localparam R_P     = 7'b1111010;

    task check4(input [6:0] e0, input [6:0] e1, input [6:0] e2, input [6:0] e3, input [127:0] msg);
        begin
            if (seg0 !== e0 || seg1 !== e1 || seg2 !== e2 || seg3 !== e3) begin
                $display("FAIL %0s: got %b %b %b %b, expected %b %b %b %b",
                          msg, seg0, seg1, seg2, seg3, e0, e1, e2, e3);
                errors = errors + 1;
            end else begin
                $display("PASS %0s: %b %b %b %b", msg, seg0, seg1, seg2, seg3);
            end
        end
    endtask

    // Pulse the pan clock level for one slow-clock period (level-based,
    // matching how a real clkdiv output behaves).
    task pan_tick;
        begin
            @(negedge clk); pan_clk_level = 0;
            @(negedge clk); pan_clk_level = 1;
            @(negedge clk);
        end
    endtask

    initial begin
        @(negedge clk); reset = 1;
        @(negedge clk); reset = 0;
        @(negedge clk); string_select = 2'b01; // force a real transition (Icarus won't evaluate always@(*) off a bare initializer)
        @(posedge clk); #1;

        // Letter-decode check at position 0: "STAR" (S,T,A,R).
        check4(S_P, T_P, A_P, R_P, "pos0 = STAR");

        // Walk the circular window through one full lap and confirm the
        // exact STAR/TART/ART_/RT_S/T_ST/_STA loop from the bug report.
        pan_enable = 1;
        pan_tick(); #1; check4(T_P, A_P, R_P, T_P, "pos1 = TART");
        pan_tick(); #1; check4(A_P, R_P, T_P, BLANK_P, "pos2 = ART_");
        pan_tick(); #1; check4(R_P, T_P, BLANK_P, S_P, "pos3 = RT_S");
        pan_tick(); #1; check4(T_P, BLANK_P, S_P, T_P, "pos4 = T_ST");
        pan_tick(); #1; check4(BLANK_P, S_P, T_P, A_P, "pos5 = _STA");
        pan_tick(); #1; check4(S_P, T_P, A_P, R_P, "pos6 (wrapped) = STAR again");

        // pan_load snaps straight back to position 0's window.
        pan_tick(); pan_tick(); // move off position 0 first
        @(negedge clk); pan_load = 1;
        @(posedge clk); #1;
        @(negedge clk); pan_load = 0;
        check4(S_P, T_P, A_P, R_P, "pan_load resets to STAR (pos0)");

        // OFF (string_select=00) must show a clean, static "OFF ".
        pan_enable = 0;
        @(negedge clk); string_select = 2'b00; pan_load = 1;
        @(posedge clk); #1;
        @(negedge clk); pan_load = 0;
        #1;
        if (seg0 !== 7'b0000001 || seg1 !== 7'b0111000 || seg2 !== 7'b0111000 || seg3 !== BLANK_P) begin
            $display("FAIL OFF display: got %b %b %b %b, expected O,F,F,blank", seg0, seg1, seg2, seg3);
            errors = errors + 1;
        end else $display("PASS OFF display: O, F, F, blank (no OOFF regression)");

        if (errors == 0) $display("ALL SCROLLING_TEXT_ENGINE UNIT TESTS PASSED");
        else              $display("%0d SCROLLING_TEXT_ENGINE UNIT TEST(S) FAILED", errors);
        $finish;
    end
endmodule
