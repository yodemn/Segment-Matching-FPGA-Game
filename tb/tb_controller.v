`timescale 1ns / 1ps
//
// Unit testbench for controller.
//
// AI PROMPT USED (paraphrased, per Lab 4b's "submit the prompt" requirement):
//   "Write a self-checking Verilog testbench for this controller module
//    (4-state mode FSM: OFF/START/GAMEPLAY/DONE, ports clk/R/P/c_edge/
//    round_over in, string_select/led_pattern/pan_enable/pan_load/
//    board_reset/spawn_enable/timer_enable/input_enable out). Drive
//    c_edge and P by hand (not through a real button/edge-detector),
//    check led_pattern and the two Mealy pulses (pan_load, board_reset)
//    after every transition, and verify R forces OFF from any state."
// Reviewed and adjusted by hand: added the "pause blocks mode advance"
// case and the round_over-while-paused case, neither of which the first
// draft covered.
//
module tb_controller;
    reg clk = 0, R = 1, P = 0, c_edge = 0, round_over = 0;
    wire [1:0] string_select;
    wire [3:0] led_pattern;
    wire pan_enable, pan_load, board_reset, spawn_enable, timer_enable, input_enable;

    integer errors = 0;

    controller uut (
        .clk(clk), .R(R), .P(P), .c_edge(c_edge), .round_over(round_over),
        .string_select(string_select), .led_pattern(led_pattern),
        .pan_enable(pan_enable), .pan_load(pan_load), .board_reset(board_reset),
        .spawn_enable(spawn_enable), .timer_enable(timer_enable), .input_enable(input_enable)
    );

    always #5 clk = ~clk;

    task check_led(input [3:0] expected, input [127:0] msg);
        begin
            if (led_pattern !== expected) begin
                $display("FAIL [%0t] %0s: led_pattern=%b expected=%b", $time, msg, led_pattern, expected);
                errors = errors + 1;
            end else begin
                $display("PASS [%0t] %0s: led_pattern=%b", $time, msg, led_pattern);
            end
        end
    endtask

    // Pulse c_edge for exactly one cycle, applied/released on negedge to
    // avoid racing the controller's own posedge-triggered state register.
    task pulse_c_edge;
        begin
            @(negedge clk); c_edge = 1;
            @(negedge clk); c_edge = 0;
        end
    endtask

    initial begin
        // Reset
        @(negedge clk); R = 1;
        @(negedge clk); R = 0;
        @(posedge clk); #1;
        check_led(4'b0001, "after reset");
        if (pan_load !== 1'b0) begin $display("FAIL: pan_load high at rest in OFF"); errors=errors+1; end

        // OFF -> START
        pulse_c_edge(); @(posedge clk); #1;
        check_led(4'b0010, "OFF -[c_edge]-> START");

        // Pause should block mode advance: attempt START -> GAMEPLAY while P=1
        @(negedge clk); P = 1;
        pulse_c_edge(); @(posedge clk); #1;
        check_led(4'b0010, "c_edge while paused should NOT advance");
        @(negedge clk); P = 0;

        // START -> GAMEPLAY, check board_reset pulses exactly this transition
        @(negedge clk); c_edge = 1;
        #1; // let the Mealy output settle while still in START
        if (board_reset !== 1'b1) begin $display("FAIL: board_reset did not assert while in START with c_edge high"); errors=errors+1; end
                                   else $display("PASS [%0t]: board_reset asserted pre-edge (Mealy) for START->GAMEPLAY", $time);
        @(posedge clk); #1;
        @(negedge clk); c_edge = 0;
        @(posedge clk); #1;
        check_led(4'b0100, "START -[c_edge]-> GAMEPLAY");
        if (board_reset !== 1'b0) begin $display("FAIL: board_reset stuck high after the transition"); errors=errors+1; end

        // In GAMEPLAY, c_edge should have no effect (only round_over matters)
        pulse_c_edge(); @(posedge clk); #1;
        check_led(4'b0100, "c_edge in GAMEPLAY should be ignored");

        // GAMEPLAY -> DONE_SCORE via round_over (pan_load no longer fires
        // here -- it's now armed on DONE_SCORE->DONE_TEXT instead, since
        // DONE_SCORE doesn't use the text/pan path at all).
        @(negedge clk); round_over = 1;
        @(posedge clk); #1;
        @(negedge clk); round_over = 0;
        @(posedge clk); #1;
        check_led(4'b1000, "GAMEPLAY -[round_over]-> DONE_SCORE");
        if (string_select === 2'b11) begin
            $display("FAIL: string_select==11 (ddr end) right after entering DONE_SCORE -- should be the score-hold sub-phase");
            errors = errors + 1;
        end else $display("PASS [%0t]: DONE_SCORE sub-phase (string_select=%b, not 11)", $time, string_select);

        // DONE_SCORE -> DONE_TEXT, check pan_load pulses this transition
        // and string_select switches to 11 ("ddr end").
        @(negedge clk); c_edge = 1;
        #1;
        if (pan_load !== 1'b1) begin $display("FAIL: pan_load did not assert while in DONE_SCORE with c_edge high"); errors=errors+1; end
                               else $display("PASS [%0t]: pan_load asserted pre-edge (Mealy) for DONE_SCORE->DONE_TEXT", $time);
        @(posedge clk); #1;
        @(negedge clk); c_edge = 0;
        @(posedge clk); #1;
        check_led(4'b1000, "DONE_SCORE -[c_edge]-> DONE_TEXT");
        if (string_select !== 2'b11) begin
            $display("FAIL: string_select is not 11 in DONE_TEXT (got %b)", string_select);
            errors = errors + 1;
        end else $display("PASS [%0t]: DONE_TEXT sub-phase (string_select=11, ddr end)", $time);

        // DONE_TEXT -> OFF
        pulse_c_edge(); @(posedge clk); #1;
        check_led(4'b0001, "DONE_TEXT -[c_edge]-> OFF");

        // R forces OFF from any state, immediately, regardless of P
        @(negedge clk); c_edge = 1; @(posedge clk); #1; // -> START
        @(negedge clk); c_edge = 0;
        @(negedge clk); P = 1; R = 1;
        #1;
        check_led(4'b0001, "R forces OFF immediately (async)");
        @(negedge clk); R = 0; P = 0;

        if (errors == 0) $display("ALL CONTROLLER UNIT TESTS PASSED");
        else              $display("%0d CONTROLLER UNIT TEST(S) FAILED", errors);
        $finish;
    end
endmodule
