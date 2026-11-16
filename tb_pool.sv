`timescale 1ns / 1ps

module tb_pool;

    // Tín hiệu kết nối với DUT (Design Under Test)
    reg               clk;
    reg               rst;
    reg  signed [7:0] data_in;
    reg               wr_en;
    reg         [7:0] row_size;
    reg               start;

    wire signed [7:0] data_out;
    wire              data_valid;
    wire              pool_done;

    // Khởi tạo module cần test
    pool uut (
        .clk        (clk),
        .rst        (rst),
        .data_in    (data_in),
        .wr_en      (wr_en),
        .row_size   (row_size),
        .start      (start),
        .data_out   (data_out),
        .data_valid (data_valid),
        .pool_done  (pool_done)
    );

    // Tạo xung clock 100MHz (chu kỳ 10ns)
    always #5 clk = ~clk;

    // Mảng lưu ma trận đầu vào và kết quả kỳ vọng (tối đa 28x28)
    reg signed [7:0] img_mem      [0:27][0:27];
    reg signed [7:0] expected_out [0:13][0:13];

    integer out_r, out_c;
    integer err_cnt;

    // ---------------------------------------------------------
    // Task chạy một bài test với kích thước N x N và chế độ stall
    // stall_en = 1: giả lập wr_en ngắt quãng để test luồng dữ liệu thực tế
    // ---------------------------------------------------------
    task run_pool_test;
        input [7:0] size;
        input       stall_en;
        integer r, c;
        reg signed [9:0] sum4;
        begin
            $display("\n--- BAT DAU TEST: Kich thuoc %0dx%0d | Stall wr_en = %0d ---", size, size, stall_en);
            
            // 1. Sinh dữ liệu ngẫu nhiên có dấu (-128 đến 127)
            for (r = 0; r < size; r = r + 1) begin
                for (c = 0; c < size; c = c + 1) begin
                    img_mem[r][c] = $random; 
                end
            end

            // 2. Tính trước kết quả kỳ vọng (Golden Model)
            for (r = 0; r < size; r = r + 2) begin
                for (c = 0; c < size; c = c + 2) begin
                    sum4 = img_mem[r][c] + img_mem[r][c+1] + 
                           img_mem[r+1][c] + img_mem[r+1][c+1];
                    // Dùng phép dịch số học >>> 2 để khớp với sum[9:2]
                    expected_out[r/2][c/2] = sum4 >>> 2; 
                end
            end

            // 3. Cấp xung start trong 1 chu kỳ clock
            @(posedge clk);
            row_size <= size;
            start    <= 1'b1;
            wr_en    <= 1'b0;
            out_r    <= 0;
            out_c    <= 0;

            @(posedge clk);
            start    <= 1'b0; // Hạ start trước khi đẩy pixel đầu tiên

            // 4. Đẩy từng pixel theo thứ tự raster-scan
            for (r = 0; r < size; r = r + 1) begin
                for (c = 0; c < size; c = c + 1) begin
                    // Nếu bật stall_en, ngẫu nhiên chèn chu kỳ wr_en = 0
                    if (stall_en) begin
                        while (($random % 3) == 0) begin
                            wr_en   <= 1'b0;
                            data_in <= 8'sd0;
                            @(posedge clk);
                        end
                    end

                    wr_en   <= 1'b1;
                    data_in <= img_mem[r][c];
                    @(posedge clk);
                end
            end

            // Ngừng ghi sau khi đẩy hết ma trận
            wr_en   <= 1'b0;
            data_in <= 8'sd0;

            // Đợi thêm vài chu kỳ để đảm bảo các tín hiệu kết thúc ổn định
            repeat (5) @(posedge clk);

            // Kiểm tra xem đã nhận đủ số lượng phần tử đầu ra chưa
            if (out_r != (size / 2) || out_c != 0) begin
                $display("[FAIL] Thieu du lieu dau ra! Moi nhan den hang %0d, cot %0d", out_r, out_c);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    // ---------------------------------------------------------
    // Khối giám sát (Monitor) tự động kiểm tra đầu ra mỗi chu kỳ
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (!rst && data_valid) begin
            if (data_out !== expected_out[out_r][out_c]) begin
                $display("[ERROR] Tai out[%0d][%0d]: Nhan = %0d, Ky vong = %0d", 
                         out_r, out_c, data_out, expected_out[out_r][out_c]);
                err_cnt = err_cnt + 1;
            end

            // Kiểm tra cờ pool_done phải bật đúng ở phần tử cuối cùng
            if ((out_r == (row_size/2 - 1)) && (out_c == (row_size/2 - 1))) begin
                if (!pool_done) begin
                    $display("[ERROR] Phan tu cuoi cung nhung pool_done khong bat!");
                    err_cnt = err_cnt + 1;
                end else begin
                    $display("[OK] Nhan du %0dx%0d ket qua va pool_done bat dung thoi diem.", row_size/2, row_size/2);
                end
            end else if (pool_done) begin
                $display("[ERROR] pool_done bat qua som tai out[%0d][%0d]!", out_r, out_c);
                err_cnt = err_cnt + 1;
            end

            // Cập nhật tọa độ đầu ra tiếp theo
            if (out_c == (row_size / 2) - 1) begin
                out_c <= 0;
                out_r <= out_r + 1;
            end else begin
                out_c <= out_c + 1;
            end
        end
    end

    // ---------------------------------------------------------
    // Luồng thực thi chính
    // ---------------------------------------------------------
    initial begin
        // Xuất file waveform để xem trên GTKWave / ModelSim
        $dumpfile("tb_pool.vcd");
        $dumpvars(0, tb_pool);

        // Khởi tạo tín hiệu
        clk      = 0;
        rst      = 1;
        data_in  = 0;
        wr_en    = 0;
        row_size = 0;
        start    = 0;
        err_cnt  = 0;

        // Giữ reset 3 chu kỳ
        repeat (3) @(posedge clk);
        rst = 0;

        // Test 1: Ma trận 10x10 đẩy dữ liệu liên tục
        run_pool_test(8'd10, 1'b0);

        // Test 2: Ma trận 28x28 (kích thước tối đa) đẩy dữ liệu liên tục
        run_pool_test(8'd28, 1'b0);

        // Test 3: Ma trận 28x28 với wr_en ngắt quãng (test backpressure/stall)
        run_pool_test(8'd28, 1'b1);

        // Tổng kết
        $display("\n==========================================");
        if (err_cnt == 0)
            $display("KET QUA: PASS TOAN BO CAC TEST CASE!");
        else
            $display("KET QUA: FAIL VOI %0d LOI!", err_cnt);
        $display("==========================================\n");
        $finish;
    end

endmodule