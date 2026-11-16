`timescale 1ns / 1ps
// Testbench tu kiem tra cho argmax.v
module tb_argmax;

    reg                clk = 0;
    reg                rst = 1;
    reg  signed [7:0]  score_in = 0;
    reg                score_valid = 0;
    reg                start = 0;
    wire [3:0]         class_out;
    wire               valid_out;

    argmax dut (.clk(clk), .rst(rst), .score_in(score_in),
                .score_valid(score_valid), .start(start),
                .class_out(class_out), .valid_out(valid_out));

    always #10 clk = ~clk;                 // 50 MHz

    integer errors = 0;
    integer tests  = 0;
    integer pulses;                        // dem so valid_out trong 1 lan chay

    always @(posedge clk) if (valid_out) pulses = pulses + 1;

    reg signed [7:0] s [0:9];

    // Mo hinh tham chieu: index nho nhat cua gia tri lon nhat
    function [3:0] ref_argmax(input integer dummy);
        integer i; reg signed [7:0] m; reg [3:0] idx;
        begin
            m = s[0]; idx = 0;
            for (i = 1; i < 10; i = i + 1)
                if (s[i] > m) begin m = s[i]; idx = i; end
            ref_argmax = idx;
        end
    endfunction

    // gap = so cycle trong giua cac score (0 = lien tuc)
    task run_case(input integer gap, input integer start_with_first);
        integer i, k;
        begin
            pulses = 0;
            @(negedge clk);
            start = 1;
            if (start_with_first) begin
                score_in = s[0]; score_valid = 1;
            end
            @(negedge clk);
            start = 0; score_valid = 0;
            for (i = start_with_first ? 1 : 0; i < 10; i = i + 1) begin
                score_in = s[i]; score_valid = 1;
                @(negedge clk);
                score_valid = 0;
                for (k = 0; k < gap; k = k + 1) @(negedge clk);
            end
            repeat (3) @(negedge clk);
            tests = tests + 1;
            if (pulses !== 1) begin
                errors = errors + 1;
                $display("FAIL: valid_out pulse count = %0d (can 1)", pulses);
            end
            if (class_out !== ref_argmax(0)) begin
                errors = errors + 1;
                $display("FAIL: got %0d, expected %0d  scores=%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d",
                         class_out, ref_argmax(0),
                         s[0],s[1],s[2],s[3],s[4],s[5],s[6],s[7],s[8],s[9]);
            end
        end
    endtask

    integer n, j;
    initial begin
        repeat (3) @(negedge clk);
        rst = 0;

        // --- Directed ---
        for (j = 0; j < 10; j = j + 1) s[j] = j;          run_case(0, 0); // max o cuoi (9)
        for (j = 0; j < 10; j = j + 1) s[j] = 9 - j;      run_case(0, 0); // max o dau (0)
        for (j = 0; j < 10; j = j + 1) s[j] = -128;       run_case(0, 0); // toan -128 -> 0
        for (j = 0; j < 10; j = j + 1) s[j] = 127;        run_case(0, 0); // hoa -> 0
        for (j = 0; j < 10; j = j + 1) s[j] = -1 - j;     run_case(0, 0); // toan am -> 0
        for (j = 0; j < 10; j = j + 1) s[j] = -100;
        s[5] = -3;                                        run_case(0, 0); // am, max o 5
        for (j = 0; j < 10; j = j + 1) s[j] = 10;
        s[3] = 50; s[7] = 50;                             run_case(0, 0); // hoa -> chon 3
        for (j = 0; j < 10; j = j + 1) s[j] = 0;
        s[0] = -128; s[9] = 127;                          run_case(0, 0); // bien

        // --- Random: lien tuc, co khoang trong, start cung luc score dau ---
        for (n = 0; n < 2000; n = n + 1) begin
            for (j = 0; j < 10; j = j + 1) s[j] = $random;
            run_case(n % 3, (n % 5) == 0);
        end

        $display("=======================================");
        if (errors == 0) $display("PASS: %0d test case, 0 loi", tests);
        else             $display("FAIL: %0d loi / %0d test case", errors, tests);
        $display("=======================================");
        $finish;
    end
endmodule
