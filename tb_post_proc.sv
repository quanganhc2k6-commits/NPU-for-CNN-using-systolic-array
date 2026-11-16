`timescale 1ns / 1ps

module tb_post_proc;

    // Tín hiệu kết nối với DUT
    reg                clk;
    reg                rst;
    reg  signed [31:0] acc_in;
    reg         [7:0]  scale;
    reg         [3:0]  shift;
    reg                valid_in;

    wire signed [7:0]  result_out;
    wire               valid_out;

    // Khởi tạo module post_proc
    post_proc uut (
        .clk        (clk),
        .rst        (rst),
        .acc_in     (acc_in),
        .scale      (scale),
        .shift      (shift),
        .valid_in   (valid_in),
        .result_out (result_out),
        .valid_out  (valid_out)
    );

    // Tạo xung clock 100MHz (chu kỳ 10ns)
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // Golden Reference Pipeline (mô phỏng độ trễ 3 chu kỳ của DUT)
    // ---------------------------------------------------------
    reg signed [7:0] exp_pipe_data  [0:2];
    reg              exp_pipe_valid [0:2];

    // Hàm tính toán kết quả chuẩn tại chu kỳ hiện tại
    function signed [7:0] calc_expected;
        input signed [31:0] f_acc;
        input        [7:0]  f_scale;
        input        [3:0]  f_shift;
        reg          [30:0] relu_val;
        reg          [38:0] mult_val;
        reg          [38:0] shift_val;
        begin
            // 1. ReLU
            relu_val  = (f_acc < 0) ? 31'd0 : f_acc[30:0];
            // 2. Multiply
            mult_val  = relu_val * f_scale;
            // 3. Shift
            shift_val = mult_val >> f_shift;
            // 4. Clamp về [0, 127]
            calc_expected = (shift_val > 39'd127) ? 8'sd127 : shift_val[7:0];
        end
    endfunction

    // Dịch chuyển giá trị kỳ vọng qua 3 tầng thanh ghi theo clock
    always @(posedge clk) begin
        if (rst) begin
            exp_pipe_valid[0] <= 1'b0;
            exp_pipe_valid[1] <= 1'b0;
            exp_pipe_valid[2] <= 1'b0;
            exp_pipe_data[0]  <= 8'sd0;
            exp_pipe_data[1]  <= 8'sd0;
            exp_pipe_data[2]  <= 8'sd0;
        end else begin
            exp_pipe_data[0]  <= calc_expected(acc_in, scale, shift);
            exp_pipe_valid[0] <= valid_in;

            exp_pipe_data[1]  <= exp_pipe_data[0];
            exp_pipe_valid[1] <= exp_pipe_valid[0];

            exp_pipe_data[2]  <= exp_pipe_data[1];
            exp_pipe_valid[2] <= exp_pipe_valid[1];
        end
    end

    // ---------------------------------------------------------
    // Khối giám sát (Monitor): Tự động so sánh ở đầu ra mỗi chu kỳ
    // ---------------------------------------------------------
    integer pass_cnt = 0;
    integer err_cnt  = 0;

    always @(posedge clk) begin
        if (!rst) begin
            // Kiểm tra tín hiệu valid_out có trễ đúng 3 chu kỳ so với valid_in không
            if (valid_out !== exp_pipe_valid[2]) begin
                $display("[ERROR] Sai lech valid_out tai thoi diem %0t: Nhan = %b, Ky vong = %b",
                         $time, valid_out, exp_pipe_valid[2]);
                err_cnt = err_cnt + 1;
            end

            // Khi valid_out = 1, kiểm tra giá trị result_out
            if (valid_out && exp_pipe_valid[2]) begin
                if (result_out !== exp_pipe_data[2]) begin
                    $display("[ERROR] Sai lech du lieu tai thoi diem %0t: Nhan = %0d, Ky vong = %0d",
                             $time, result_out, exp_pipe_data[2]);
                    err_cnt = err_cnt + 1;
                end else begin
                    pass_cnt = pass_cnt + 1;
                end
            end
        end
    end

    // ---------------------------------------------------------
    // Task đẩy 1 mẫu dữ liệu vào pipeline trong 1 chu kỳ
    // ---------------------------------------------------------
    task send_sample;
        input signed [31:0] t_acc;
        input        [7:0]  t_scale;
        input        [3:0]  t_shift;
        input               t_valid;
        begin
            @(posedge clk);
            acc_in   <= t_acc;
            scale    <= t_scale;
            shift    <= t_shift;
            valid_in <= t_valid;
        end
    endtask

    // ---------------------------------------------------------
    // Kịch bản kiểm thử chính
    // ---------------------------------------------------------
    integer i;
    reg signed [31:0] rand_acc;
    reg        [7:0]  rand_scale;
    reg        [3:0]  rand_shift;
    reg               rand_valid;

    initial begin
        $dumpfile("tb_post_proc.vcd");
        $dumpvars(0, tb_post_proc);

        // Khởi tạo
        clk      = 0;
        rst      = 1;
        acc_in   = 0;
        scale    = 0;
        shift    = 0;
        valid_in = 0;

        repeat (3) @(posedge clk);
        rst = 0;

        $display("\n--- 1. TEST CAC TRUONG HOP BIEN (DIRECTED TESTS) ---");
        // Case 1: Số âm -> ReLU cắt về 0
        send_sample(-32'sd5000, 8'd200, 4'd4, 1'b1);
        // Case 2: Số âm nhỏ nhất của INT32 (-2^31) -> ReLU phải ra 0, không bị tràn thành dương
        send_sample(-32'sd2147483648, 8'd255, 4'd0, 1'b1);
        // Case 3: Giá trị bằng 0 -> Ra 0
        send_sample(32'sd0, 8'd128, 4'd5, 1'b1);
        // Case 4: Tính toán thông thường: (100 * 10) >> 3 = 1000 / 8 = 125 (dưới ngưỡng 127)
        send_sample(32'sd100, 8'd10, 4'd3, 1'b1);
        // Case 5: Chạm đúng ngưỡng 127: (127 * 16) >> 4 = 127
        send_sample(32'sd127, 8'd16, 4'd4, 1'b1);
        // Case 6: Vượt ngưỡng 127 -> Bão hòa (Clamp) về 127: (128 * 16) >> 4 = 128 -> 127
        send_sample(32'sd128, 8'd16, 4'd4, 1'b1);
        // Case 7: Giá trị dương rất lớn -> Không bị tràn phép nhân 39-bit, clamp về 127
        send_sample(32'sd2147483647, 8'd255, 4'd2, 1'b1);
        // Case 8: Ngắt valid_in = 0 (dữ liệu rác không được làm bật valid_out)
        send_sample(32'sd99999, 8'd255, 4'd0, 1'b0);

        $display("--- 2. TEST NGHIEM NGAT PIPELINE NGAU NHIEN (1000 MAU) ---");
        for (i = 0; i < 1000; i = i + 1) begin
            rand_acc   = $random;
            rand_scale = $random;
            rand_shift = $random;
            // Tỷ lệ valid_in = 1 khoảng 75% để test xen kẽ các khoảng trống (bubble) trong pipeline
            rand_valid = (($random & 8'hFF) < 8'd192);
            send_sample(rand_acc, rand_scale, rand_shift, rand_valid);
        end

        // Đẩy thêm 5 chu kỳ trống để xả hết dữ liệu còn lại trong pipeline
        repeat (5) send_sample(32'sd0, 8'd0, 4'd0, 1'b0);

        // Báo cáo kết quả
        $display("\n==========================================");
        $display("Tong so mau hop le da kiem tra: %0d", pass_cnt);
        if (err_cnt == 0)
            $display("KET QUA: PASS TOAN BO CAC TEST CASE!");
        else
            $display("KET QUA: FAIL VOI %0d LOI!", err_cnt);
        $display("==========================================\n");
        $finish;
    end

endmodule