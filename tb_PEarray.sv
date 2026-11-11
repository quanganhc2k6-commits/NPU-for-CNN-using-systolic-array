`timescale 1ns/1ps

module tb_pe;

    // --------------------------------------------------
    // 1. Khai báo Tham số & Tín hiệu
    // --------------------------------------------------
    parameter CLK_PERIOD = 10; // Chu kỳ xung nhịp 10ns (100MHz)

    // Inputs cho DUT
    logic        clk;
    logic        rst;
    logic        en;
    logic        load_weight;
    logic signed [7:0]  weight_in;
    logic signed [7:0]  act_in;
    logic signed [31:0] psum_in;

    // Outputs từ DUT
    logic signed [31:0] psum_out;

    // --------------------------------------------------
    // 2. Kết nối DUT (Device Under Test)
    // --------------------------------------------------
    pe u_pe (
        .clk         (clk),
        .rst         (rst),
        .en          (en),
        .load_weight (load_weight),
        .weight_in   (weight_in),
        .act_in      (act_in),
        .psum_in     (psum_in),
        .psum_out    (psum_out)
    );

    // --------------------------------------------------
    // 3. Khối tạo Xung nhịp (Clock Generator)
    // --------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // --------------------------------------------------
    // 4. Task hỗ trợ test & tự động kiểm tra (Self-Checking)
    // --------------------------------------------------
    task automatic drive_and_check(
        input logic        i_en,
        input logic signed [7:0]  i_act,
        input logic signed [31:0] i_psum,
        input logic signed [31:0] expected_psum
    );
        begin
            @(posedge clk);
            en      <= i_en;
            act_in  <= i_act;
            psum_in <= i_psum;

            // Chờ đến chu kỳ tiếp theo để kiểm tra kết quả đầu ra (do pe có pipeline 1 stage)
            @(posedge clk);
            #1; // Delay nhỏ sau cạnh lên để tránh race condition khi read
            
            assert (psum_out === expected_psum)
                $display("[PASS] Time=%0t | Act=%0d | Psum_in=%0d | Output=%0d", $time, i_act, i_psum, psum_out);
            else
                $error("[FAIL] Time=%0t | Act=%0d | Psum_in=%0d | Output=%0d (Expected: %0d)", 
                       $time, i_act, i_psum, psum_out, expected_psum);
        end
    endtask

    // --------------------------------------------------
    // 5. Kịch bản kiểm thử chính (Test Sequence)
    // --------------------------------------------------
    initial begin
        // --- 0. Khởi tạo giá trị ban đầu ---
        rst         = 1;
        en          = 0;
        load_weight = 0;
        weight_in   = 8'sd0;
        act_in      = 8'sd0;
        psum_in     = 32'sd0;

        $display("\n--------------------------------------------------");
        $display("          BAT DAU SIMULATION TESTBENCH PE         ");
        $display("--------------------------------------------------\n");

        // --- 1. Kiểm tra Reset ---
        #(CLK_PERIOD * 2);
        rst = 0;
        #(CLK_PERIOD);
        
        assert (psum_out === 32'sd0)
            $display("[PASS] Reset thanh cong, psum_out = 0");
        else
            $error("[FAIL] Reset thất bại, psum_out = %0d", psum_out);

        // --- 2. Test Case 1: Load Weight = 5 ---
        $display("\n--- Test Case 1: Load Weight = 5 ---");
        @(posedge clk);
        load_weight <= 1'b1;
        weight_in   <= 8'sd5;
        
        @(posedge clk);
        load_weight <= 1'b0;
        weight_in   <= 8'sd0; // Xóa weight_in để đảm bảo weight đã được lưu giữ cố định

        // --- 3. Test Case 2: Phép tính số dương ---
        // Act = 4, Psum_in = 10 -> Expected = 5 * 4 + 10 = 30
        $display("\n--- Test Case 2: Positive Numbers (Weight=5, Act=4, Psum_in=10) ---");
        drive_and_check(1'b1, 8'sd4, 32'sd10, 32'sd30);

        // --- 4. Test Case 3: Phép tính số âm ---
        // Act = -3, Psum_in = 30 -> Expected = 5 * (-3) + 30 = 15
        $display("\n--- Test Case 3: Negative Numbers (Weight=5, Act=-3, Psum_in=30) ---");
        drive_and_check(1'b1, -8'sd3, 32'sd30, 32'sd15);

        // --- 5. Test Case 4: Load Weight mới (Số âm: Weight = -10) ---
        $display("\n--- Test Case 4: Load New Negative Weight = -10 ---");
        @(posedge clk);
        load_weight <= 1'b1;
        weight_in   <= -8'sd10;

        @(posedge clk);
        load_weight <= 1'b0;

        // Weight = -10, Act = -6, Psum_in = 15 -> Expected = (-10)*(-6) + 15 = 75
        drive_and_check(1'b1, -8'sd6, 32'sd15, 32'sd75);

        // --- 6. Test Case 5: Tín hiệu Enable (en = 0) ---
        // Khi en = 0, psum_out phải giữ nguyên giá trị cũ (75) bất chấp act_in thay đổi
        $display("\n--- Test Case 5: Enable = 0 (Hold value) ---");
        @(posedge clk);
        en      <= 1'b0;
        act_in  <= 8'sd10;
        psum_in <= 32'sd100;

        @(posedge clk);
        #1;
        assert (psum_out === 32'sd75)
            $display("[PASS] en=0: psum_out giu nguyen gia tri cu = 75");
        else
            $error("[FAIL] en=0: psum_out bi thay doi thanh = %0d", psum_out);

        // --- Kết thúc Mô phỏng ---
        $display("\n--------------------------------------------------");
        $display("         HOAN THANH SIMULATION TESTBENCH PE       ");
        $display("--------------------------------------------------\n");
        #(CLK_PERIOD * 5);
        $finish;
    end

    // --------------------------------------------------
    // 6. Ghi Waveform (Dùng cho EDA Playground/GTKWave)
    // --------------------------------------------------
    initial begin
        $dumpfile("tb_pe.vcd");
        $dumpvars(0, tb_pe);
    end

endmodule