`timescale 1ns/1ps
module tb_byte_packer;
    reg         clk = 0, rst = 1, clr = 0, byte_en = 0;
    reg  [7:0]  byte_in = 0;
    wire [15:0] word_out;
    wire        word_valid;
    integer     errors = 0, wcnt = 0;
    reg  [15:0] words [0:15];

    byte_packer #(.DATA_W(16)) dut (
        .clk(clk), .rst(rst), .clr(clr),
        .byte_in(byte_in), .byte_en(byte_en),
        .word_out(word_out), .word_valid(word_valid)
    );

    always #5 clk = ~clk;

    // Ghi lại mọi từ được phát ra (mỗi chu kỳ word_valid=1 tính là 1 từ,
    // nên xung dài hơn 1 chu kỳ sẽ bị phát hiện qua wcnt)
    always @(posedge clk) if (word_valid) begin
        words[wcnt] = word_out;
        wcnt = wcnt + 1;
    end

    task send_byte(input [7:0] b);
        begin byte_en <= 1; byte_in <= b; @(posedge clk); end
    endtask

    task idle(input integer n);
        begin byte_en <= 0; repeat (n) @(posedge clk); end
    endtask

    task expect_cnt(input integer n);
        begin
            #1;
            if (wcnt !== n) begin
                errors = errors + 1;
                $display("FAIL: so tu = %0d, mong doi %0d", wcnt, n);
            end
        end
    endtask

    task expect_word(input integer idx, input [15:0] e);
        begin
            if (words[idx] !== e) begin
                errors = errors + 1;
                $display("FAIL: words[%0d]=%h, mong doi %h", idx, words[idx], e);
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk); rst <= 0;

        // 1) 2 byte -> 1 từ, byte đến trước nằm ở phần cao
        send_byte(8'h12); send_byte(8'h34); idle(3);
        expect_cnt(1); expect_word(0, 16'h1234);

        // 2) Có khoảng trống giữa các byte
        send_byte(8'hAB); idle(2);
        send_byte(8'hCD); idle(1);
        send_byte(8'hEF); idle(4);
        send_byte(8'h01); idle(3);
        expect_cnt(3); expect_word(1, 16'hABCD); expect_word(2, 16'hEF01);

        // 3) clr xóa byte đang gom dở: 55 bị bỏ, từ mới phải là 6677
        send_byte(8'h55); idle(1);
        clr <= 1; @(posedge clk); clr <= 0;
        send_byte(8'h66); send_byte(8'h77); idle(3);
        expect_cnt(4); expect_word(3, 16'h6677);

        // 4) Byte liên tiếp, không có khoảng trống
        send_byte(8'h11); send_byte(8'h22); send_byte(8'h33); send_byte(8'h44); idle(3);
        expect_cnt(6); expect_word(4, 16'h1122); expect_word(5, 16'h3344);

        // 5) rst xóa byte đang gom dở
        send_byte(8'h99); idle(1);
        rst <= 1; @(posedge clk); rst <= 0;
        send_byte(8'hAA); send_byte(8'hBB); idle(3);
        expect_cnt(7); expect_word(6, 16'hAABB);

        if (errors == 0) $display("PASS: tb_byte_packer");
        else             $display("FAIL: %0d loi", errors);
        $finish;
    end
endmodule