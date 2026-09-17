`timescale 1ns / 1ps
module tb_smoke;
    reg clk = 0, R = 1, P = 0, S = 0, SF = 0, SG = 0;
    reg BTNU=0, BTND=0, BTNL=0, BTNR=0, BTNC=0;
    wire [6:0] seg;
    wire [3:0] an;
    wire [15:0] led;

    ddr_top #(
        .PAN_WIDTH(3), .TIMER_WIDTH(4), .REFRESH_WIDTH(2), .SPAWN_LIMIT(9), .TIMER_START(4)
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

    initial begin
        $display("time led seg an  (R=%b)", R);
        #20 R = 0;
        #40;
        $display("[%0t] after reset: led=%b (expect 0001)", $time, led[3:0]);

        press_btnc(); #20;
        $display("[%0t] after 1 press: led=%b state=%b (expect 0010, START)", $time, led[3:0], uut.ctrl.state);

        press_btnc(); #20;
        $display("[%0t] after 2 press: led=%b state=%b (expect 0100, GAMEPLAY)", $time, led[3:0], uut.ctrl.state);

        // let gameplay run for a while, hammering button 'a' against digit S=0
        BTNU = 1;
        repeat (2000) @(posedge clk);
        BTNU = 0;
        $display("[%0t] mid-game: led=%b score=%d timer=%d board=%b",
                  $time, led[3:0], uut.dp.score, uut.dp.timer_count, uut.dp.board);

        repeat (30000) @(posedge clk);
        $display("[%0t] later: led=%b state=%b (expect 1000 if round ended)", $time, led[3:0], uut.ctrl.state);

        repeat (5000) @(posedge clk);
        press_btnc(); #20; // DONE_SCORE -> DONE_TEXT
        press_btnc(); #20; // DONE_TEXT -> OFF
        $display("[%0t] after extra presses: led=%b (expect 0001, OFF)", $time, led[3:0]);

        $display("SMOKE TEST DONE");
        $finish;
    end
endmodule
