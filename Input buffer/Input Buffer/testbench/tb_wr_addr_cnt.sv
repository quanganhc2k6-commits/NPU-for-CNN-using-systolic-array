`timescale 1ns/1ps
module tb_wr_addr_cnt;
    parameter DEPTH = 8, ADDR_W = 3;

    reg              clk = 0, rst = 1, frame_done = 0, wr_en = 0;
    wire [ADDR_W:0]  wr_addr;
    wire             full;
    integer i, errors = 0;

    wr_addr_cnt #(.DEPTH(DEPTH), .ADDR_W(ADDR_W)) dut (
        .clk(clk), .rst(rst), .frame_done(frame_done),
        .wr_en(wr_en), .wr_addr(wr_addr), .full(full)
    );

    always #5 clk = ~clk;

    task check(input integer exp_addr, input exp_full);
        begin
            @(posedge clk); #1;
            if (wr_addr !== exp_addr || full !== exp_full) begin
                errors = errors + 1;
                $display("FAIL @%0t: wr_addr=%0d full=%b, mong doi %0d / %b",
                         $time, wr_addr, full, exp_addr, exp_full);
            end
        end
    endtask

    initial begin
        // Reset
        check(0, 0);
        rst <= 0;

        // wr_en=0 thì đứng yên
        wr_en <= 0; check(0, 0);

        // Tăng 1 mỗi khi wr_en=1, full lên 1 khi chạm DEPTH
        for (i = 1; i <= DEPTH; i = i + 1) begin
            wr_en <= 1; check(i, i == DEPTH);
        end

        // Bão hòa: ghi thêm vẫn đứng ở DEPTH, không quay vòng
        repeat (3) check(DEPTH, 1);

        // wr_en=0 giữ nguyên
        wr_en <= 0; check(DEPTH, 1);

        // frame_done khi đang đầy -> về 0, full xuống 0
        frame_done <= 1; check(0, 0); frame_done <= 0;

        // Đếm lại từ đầu
        wr_en <= 1; check(1, 0); check(2, 0); check(3, 0);

        // frame_done ưu tiên hơn wr_en
        frame_done <= 1; check(0, 0); frame_done <= 0; wr_en <= 0;

        // rst giữa chừng
        wr_en <= 1; check(1, 0); check(2, 0);
        rst <= 1; check(0, 0); rst <= 0; wr_en <= 0;
        check(0, 0);

        if (errors == 0) $display("PASS: tb_wr_addr_cnt");
        else             $display("FAIL: %0d loi", errors);
        $finish;
    end
endmodule