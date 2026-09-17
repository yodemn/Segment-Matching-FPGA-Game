`timescale 1ns / 1ps
//
// Integration testbench for ddr_top.
//
// AI PROMPT USED (paraphrased):
//   "Write a top-level testbench for this FPGA design that drives a
//    100 MHz clock, a reset pulse, and synthetic button presses/pause
//    toggles, observing only led and seg/an (not internals). Verify: (1)
//    reset lands in OFF: (2) one press advances to START and panning
//    begins; (3) toggling pause freezes the pan position; (4) releasing
//    pause resumes from the frozen position, not position 0; (5) three
//    more presses cycle through GAMEPLAY, DONE, and back to OFF. Use
//    small clock-divider parameter overrides so this runs in a
//    reasonable amount of simulated time."
// Reviewed and adjusted by hand: added the GAMEPLAY round_over shortcut
// (driving the round via forced button-mashing rather than waiting out a
// full hardware-length timer) and switched every stimulus edge to
// negedge to avoid racing the DUT, which the first AI draft did not do
// and which produced exactly the false failures documented in this
// project's design notes.
//
module tb_integration;
    reg clk = 0, R = 1, P = 0, S = 0, SF = 0, SG = 0;
    reg BTNU=0, BTND=0, BTNL=0, BTNR=0, BTNC=0;
    wire [6:0] seg;
    wire [3:0] an;
    wire [15:0] led;

    integer errors = 0;

    // Tiny simulation-friendly clock dividers (see note in datapath.v /
    // Lab 4b's own warning about remembering to restore hardware values
    // before synthesis -- these parameters exist for exactly that reason).
    ddr_top #(
        .PAN_WIDTH(4), .TIMER_WIDTH(5), .REFRESH_WIDTH(2), .SPAWN_LIMIT(9), .TIMER_START(4)
    ) uut (
        .clk(clk), .R(R), .P(P), .S(S), .SF(SF), .SG(SG),
        .BTNU(BTNU), .BTND(BTND), .BTNL(BTNL), .BTNR(BTNR), .BTNC(BTNC),
        .seg(seg), .an(an), .led(led)
    );

    always #5 clk = ~clk;

    task press_btnc;
        begin
            @(negedge clk); BTNC = 1;
            @(negedge clk);
            @(negedge clk); BTNC = 0;
            @(negedge clk);
        end
    endtask

    task check_led(input [3:0] expected, input [127:0] msg);
        begin
            if (led[3:0] !== expected) begin
                $display("FAIL [%0t] %0s: led=%b expected=%b", $time, msg, led[3:0], expected);
                errors = errors + 1;
            end else begin
                $display("PASS [%0t] %0s: led=%b", $time, msg, led[3:0]);
            end
        end
    endtask

    initial begin
        // ---- Scenario 1: reset lands in OFF, display shows OFF ----
        @(negedge clk); R = 1;
        @(negedge clk); R = 0;
        @(posedge clk); #1;
        check_led(4'b0001, "Scenario 1: after reset");
        // Confirm the display path is sourced from string_select=00 ("OFF")
        // and pos never leaves 0 (no panning) -- checked via the internal
        // window, since seg/an is time-multiplexed and not directly
        // comparable to one fixed pattern at an arbitrary probe instant.
        if (uut.dp.stext.pos !== 4'd0) begin
            $display("FAIL: pos is not 0 in OFF (pos=%0d)", uut.dp.stext.pos);
            errors = errors + 1;
        end

        // ---- Scenario 2: one press -> START, panning begins ----
        press_btnc(); @(posedge clk); #1;
        check_led(4'b0010, "Scenario 2: after 1 press (START)");
        begin : pan_started
            reg [3:0] pos0;
            integer i;
            reg moved;
            pos0 = uut.dp.stext.pos;
            moved = 0;
            for (i = 0; i < 600; i = i + 1) begin
                @(posedge clk);
                if (uut.dp.stext.pos != pos0) moved = 1;
            end
            if (!moved) begin
                $display("FAIL: pos did not move after entering START (stuck at %0d)", pos0);
                errors = errors + 1;
            end else $display("PASS: pos advanced in START (started at %0d, now %0d)", pos0, uut.dp.stext.pos);
        end

        // ---- Scenario 3: pause freezes pos ----
        @(negedge clk); P = 1;
        begin : frozen
            reg [3:0] held;
            held = uut.dp.stext.pos;
            repeat (500) @(posedge clk);
            if (uut.dp.stext.pos !== held) begin
                $display("FAIL: pos moved while paused (%0d -> %0d)", held, uut.dp.stext.pos);
                errors = errors + 1;
            end else $display("PASS: pos held at %0d while paused", held);

            // ---- Scenario 4: releasing pause resumes from the frozen value ----
            @(negedge clk); P = 0;
            repeat (600) @(posedge clk);
            if (uut.dp.stext.pos == held) begin
                $display("FAIL: pos never resumed after unpausing (still %0d)", held);
                errors = errors + 1;
            end else $display("PASS: pos resumed from %0d (now %0d), not reset to 0", held, uut.dp.stext.pos);
        end

        // ---- Scenario 5: three more presses cycle GAMEPLAY -> DONE -> OFF ----
        press_btnc(); @(posedge clk); #1;
        check_led(4'b0100, "Scenario 5a: 2nd press (GAMEPLAY)");

        // Drive the round to completion quickly: mash every input against
        // both digits so score/board saturate and timer_count also runs
        // down, instead of relying on unpausing to wait out the full
        // hardware timer length.
        BTNU = 1; BTNR = 1; BTNC = 1; BTND = 1; BTNL = 1; SF = 1; SG = 1;
        repeat (4000) begin
            @(posedge clk);
            S = ~S; // alternate which digit is targeted so both get cleared
        end
        BTNU=0; BTNR=0; BTNC=0; BTND=0; BTNL=0; SF=0; SG=0;

        if (led[3:0] !== 4'b1000) begin
            $display("FAIL: round did not end into DONE_SCORE within the test window (led=%b)", led[3:0]);
            errors = errors + 1;
        end else $display("PASS: round ended into DONE_SCORE (led=1000)");

        press_btnc(); @(posedge clk); #1;
        check_led(4'b1000, "Scenario 5b: 3rd press (DONE_SCORE -> DONE_TEXT, still led=1000)");
        if (uut.dp.string_select !== 2'b11) begin
            $display("FAIL: expected string_select=11 (ddr end) in DONE_TEXT, got %b", uut.dp.string_select);
            errors = errors + 1;
        end else $display("PASS: DONE_TEXT showing ddr end (string_select=11)");

        press_btnc(); @(posedge clk); #1;
        check_led(4'b0001, "Scenario 5c: 4th press (DONE_TEXT -> OFF)");

        // ---- Regression: bug #1, R held high must not freeze the display ----
        begin : r_held_check
            reg [3:0] an0;
            @(negedge clk); R = 1;
            repeat (20) @(posedge clk);
            an0 = an;
            repeat (200) @(posedge clk);
            if (an == an0) begin
                $display("FAIL: an[] never changed while R held (display scanner frozen -- bug #1 regression)");
                errors = errors + 1;
            end else $display("PASS: an[] still cycling while R held (%b -> %b)", an0, an);
            @(negedge clk); R = 0;
            @(posedge clk); #1;
        end

        // ---- Regression: bug #5, DONE must show blank-left / frozen-score-right ----
        press_btnc(); @(posedge clk); #1; // -> START
        press_btnc(); @(posedge clk); #1; // -> GAMEPLAY
        BTNU = 1; BTNR = 1; BTNC = 1; BTND = 1; BTNL = 1; SF = 1; SG = 1;
        repeat (4000) begin
            @(posedge clk);
            S = ~S;
        end
        BTNU=0; BTNR=0; BTNC=0; BTND=0; BTNL=0; SF=0; SG=0;
        if (led[3:0] !== 4'b1000) begin
            $display("FAIL: did not reach DONE for the bug #5 regression check");
            errors = errors + 1;
        end else begin
            if (uut.dp.mgr.digit3 !== 7'b1111111 || uut.dp.mgr.digit2 !== 7'b1111111) begin
                $display("FAIL: DONE's left two digits are not blank (digit3=%b digit2=%b)", uut.dp.mgr.digit3, uut.dp.mgr.digit2);
                errors = errors + 1;
            end else $display("PASS: DONE shows blank on the left two digits");
            if (uut.dp.mgr.digit1 !== uut.dp.mgr.score_tens_seg || uut.dp.mgr.digit0 !== uut.dp.mgr.score_ones_seg) begin
                $display("FAIL: DONE's right two digits are not showing the score");
                errors = errors + 1;
            end else $display("PASS: DONE shows the frozen score on the right two digits (score=%0d)", uut.dp.score);
            // Confirm it really is frozen: wait a while, score must not change,
            // and only BTNC should move us out of DONE.
            begin
                reg [6:0] frozen_score;
                frozen_score = uut.dp.score;
                repeat (2000) @(posedge clk);
                if (uut.dp.score !== frozen_score) begin
                    $display("FAIL: score changed while sitting in DONE (%0d -> %0d)", frozen_score, uut.dp.score);
                    errors = errors + 1;
                end else $display("PASS: score stayed frozen at %0d while sitting in DONE", frozen_score);
            end
        end

        if (errors == 0) $display("ALL INTEGRATION SCENARIOS PASSED");
        else              $display("%0d INTEGRATION SCENARIO(S) FAILED", errors);
        $finish;
    end
endmodule
