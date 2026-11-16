`timescale 1ns/1ps
module tb_full_detect;
    parameter DEPTH = 8, ADDR_W = 3;

    reg             clk = 0, rst = 1, wr_en = 0;
    reg [ADDR_W:0]  wr_addr = 0;
    wire            buf_full;
    integer errors = 0;

    full_detect #(.DEPTH(DEPTH), .ADDR_W(ADDR_W)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en),
        .wr_addr(wr_addr), .buf_full(buf_full)
    );

    always #5 clk = ~clk;

    task check(input exp);
        begin
            @(posedge clk); #1;
            if (buf_full !== exp) begin
                errors = errors + 1;
                $display("FAIL @%0t: buf_full=%b, mong doi %b (addr=%0d wr_en=%b rst=%b)",
                         $time, buf_full, exp, wr_addr, wr_en, rst);
            end
        end
    endtask

    initial begin
        check(0);                 // đang reset
        rst <= 0;

        wr_en <= 1; wr_addr <= 0;         check(0);   // địa chỉ đầu
        wr_en <= 1; wr_addr <= DEPTH-2;   check(0);   // chưa tới từ cuối
        wr_en <= 0; wr_addr <= DEPTH-1;   check(0);   // từ cuối nhưng không ghi
        wr_en <= 1; wr_addr <= DEPTH-1;   check(1);   // xung lên
        wr_en <= 0; wr_addr <= DEPTH;     check(0);   // xung chỉ 1 chu kỳ
        wr_en <= 1; wr_addr <= DEPTH;     check(0);   // ghi tràn: không có xung

        // rst ưu tiên hơn điều kiện tạo xung
        wr_en <= 1; wr_addr <= DEPTH-1; rst <= 1; check(0);
        rst <= 0; wr_en <= 0;

        if (errors == 0) $display("PASS: tb_full_detect");
        else             $display("FAIL: %0d loi", errors);
        $finish;
    end
endmodule