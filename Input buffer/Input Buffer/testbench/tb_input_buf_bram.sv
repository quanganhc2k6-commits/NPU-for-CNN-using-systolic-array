`timescale 1ns/1ps
module tb_input_buf_bram;
    localparam DEPTH = 64, ADDR_W = 6, DATA_W = 16;

    reg                clk = 0, we = 0;
    reg  [ADDR_W-1:0]  wr_addr = 0, rd_addr = 0;
    reg  [DATA_W-1:0]  wr_data = 0;
    wire [DATA_W-1:0]  rd0, rd1;       // rd0: độ trễ 1, rd1: độ trễ 2
    integer i, errors = 0;

    function [DATA_W-1:0] pat(input integer k);
        pat = k*2579 + 17;
    endfunction

    input_buf_bram #(DEPTH, ADDR_W, DATA_W, 0) dut0 (
        .clk(clk), .we(we), .wr_addr(wr_addr), .wr_data(wr_data),
        .rd_addr(rd_addr), .rd_data(rd0));
    input_buf_bram #(DEPTH, ADDR_W, DATA_W, 1) dut1 (
        .clk(clk), .we(we), .wr_addr(wr_addr), .wr_data(wr_data),
        .rd_addr(rd_addr), .rd_data(rd1));

    always #5 clk = ~clk;

    // Đọc toàn bộ, so với pat(k) (hoặc giá trị override ở địa chỉ ov_addr)
    task read_all(input integer ov_addr, input [DATA_W-1:0] ov_val);
        integer k; reg [DATA_W-1:0] e;
        begin
            for (k = 0; k < DEPTH; k = k + 1) begin
                e = (k == ov_addr) ? ov_val : pat(k);
                rd_addr <= k;
                @(posedge clk); #1;
                if (rd0 !== e) begin
                    errors = errors + 1;
                    $display("FAIL (OUT_REG=0): rd[%0d]=%h, mong doi %h", k, rd0, e);
                end
                @(posedge clk); #1;
                if (rd1 !== e) begin
                    errors = errors + 1;
                    $display("FAIL (OUT_REG=1): rd[%0d]=%h, mong doi %h", k, rd1, e);
                end
            end
        end
    endtask

    initial begin
        // 1) Ghi toàn bộ DEPTH từ
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge clk); we <= 1; wr_addr <= i; wr_data <= pat(i);
        end
        @(posedge clk); we <= 0;

        // 2) Đọc lại toàn bộ (kiểm tra độ trễ 1 và 2 chu kỳ)
        read_all(-1, 0);

        // 3) we=0 thì không ghi đè: thử "ghi" giá trị luôn khác gốc vào từng ô
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(posedge clk); we <= 0; wr_addr <= i; wr_data <= ~pat(i);
        end
        @(posedge clk);
        read_all(-1, 0);

        // 4) Ghi đè hợp lệ 1 ô rồi đọc lại toàn bộ
        @(posedge clk); we <= 1; wr_addr <= 6'd5; wr_data <= 16'hBEEF;
        @(posedge clk); we <= 0;
        read_all(5, 16'hBEEF);

        if (errors == 0) $display("PASS: tb_input_buf_bram");
        else             $display("FAIL: %0d loi", errors);
        $finish;
    end
endmodule