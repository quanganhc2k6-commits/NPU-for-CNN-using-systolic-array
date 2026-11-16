`timescale 1ns / 1ps
// Testbench tu kiem tra cho spi_slave_tx (SPI Mode 0, clk 50 MHz)
// Master mo hinh: doc MISO o canh len SCLK, dong thoi kiem tra MISO da on dinh
// 10 ns TRUOC canh len (setup) va do tre MISO sau canh xuong SCLK.
module tb_spi_slave_tx;

    reg        clk = 0;
    reg        rst = 1;
    reg        SCLK = 0;
    reg        CS_N = 1;
    reg  [7:0] data_in = 8'h00;
    reg        send_en = 0;
    wire       MISO;
    wire       tx_done;

    spi_slave_tx dut (.clk(clk), .rst(rst), .SCLK(SCLK), .CS_N(CS_N),
                      .data_in(data_in), .send_en(send_en),
                      .MISO(MISO), .tx_done(tx_done));

    always #10 clk = ~clk;                   // 50 MHz

    integer errors   = 0;
    integer tests    = 0;
    integer done_cnt = 0;
    integer seed     = 32'h0bad_cafe;

    always @(posedge clk) if (tx_done) done_cnt = done_cnt + 1;

    // ---- Do tre MISO sau canh xuong SCLK (chi tinh khi CS_N thap) ----------
    realtime fall_t   = 0;
    realtime max_dly  = 0;
    realtime min_dly  = 1e9;
    integer  dly_cnt  = 0;
    always @(negedge SCLK) fall_t = $realtime;
    always @(MISO) begin
        if (!CS_N && fall_t > 0 && ($realtime - fall_t) < 90.0) begin
            if ($realtime - fall_t > max_dly) max_dly = $realtime - fall_t;
            if ($realtime - fall_t < min_dly) min_dly = $realtime - fall_t;
            dly_cnt = dly_cnt + 1;
        end
    end

    // ---- Kiem tra giao thuc: MISO khong duoc doi khi SCLK cao trong luc CS_N thap
    //      (Mode 0: slave chi doi MISO o canh xuong, giu on dinh quanh canh len)
    integer hold_viol = 0;
    always @(MISO) begin
        if (!CS_N && SCLK) begin
            hold_viol = hold_viol + 1;
            errors = errors + 1;
            if (hold_viol < 4) $display("FAIL: MISO doi khi SCLK dang cao (t=%0t)", $time);
        end
    end

    // ---- Nap byte vao module bang xung send_en (data_in chi dung 1 cycle) ---
    task load(input [7:0] d);
        begin
            @(negedge clk);
            data_in = d; send_en = 1;
            @(negedge clk);
            send_en = 0; data_in = ~d;       // doi data_in de chung to module da chot
        end
    endtask

    // ---- Master doc nbits bit. inject_at >= 0: xung send_en(inj_val) sau bit do
    task read_bits(input [7:0] exp, input integer nbits, input integer half,
                   input integer inject_at, input [7:0] inj_val,
                   input [255:0] name);
        integer k, e;
        reg early, late;
        begin
            e = 0;
            #200; CS_N = 0; #200;            // CS_N xuong, cho dong bo xong
            for (k = 0; k < nbits; k = k + 1) begin
                #(half - 10);  early = MISO;     // 10 ns truoc canh len
                #10;           SCLK  = 1;  late = MISO;   // dung canh len
                if (early !== exp[7 - k] || late !== exp[7 - k]) begin
                    e = e + 1;
                    if (e < 6) $display("FAIL [%0s]: bit %0d (MSB=0) early=%b late=%b can %b",
                                        name, k, early, late, exp[7 - k]);
                end
                #(half);       SCLK = 0;
                if (k == inject_at) load(inj_val);
            end
            #200; CS_N = 1; #400;
            errors = errors + e;
            tests  = tests + 1;
            if (e == 0) $display("PASS [%0s]", name);
        end
    endtask

    task expect_done(input integer base0, input integer want, input [255:0] name);
        begin
            tests = tests + 1;
            if (done_cnt - base0 !== want) begin
                errors = errors + 1;
                $display("FAIL [%0s]: tx_done %0d lan, can %0d", name, done_cnt - base0, want);
            end else
                $display("PASS [%0s]: tx_done %0d lan", name, want);
        end
    endtask

    integer i, db;
    reg [7:0] v;
    initial begin
        repeat (6) @(negedge clk);
        rst = 0;
        repeat (6) @(negedge clk);

        // 1) Sau reset, chua co send_en -> doc ra 0x00
        db = done_cnt;
        read_bits(8'h00, 8, 101, -1, 8'h00, "sau reset doc 0x00");
        expect_done(db, 1, "tx_done sau byte 0x00");

        // 2) Cac class 0..9 (SCLK ~4.95 MHz), moi lan 1 tx_done
        for (i = 0; i < 10; i = i + 1) begin
            db = done_cnt;
            load(i[7:0]);
            read_bits(i[7:0], 8, 101, -1, 8'h00, "class 0..9");
            if (done_cnt - db !== 1) begin
                errors = errors + 1; $display("FAIL: class %0d tx_done=%0d", i, done_cnt - db);
            end
        end

        // 3) Du 256 gia tri byte
        for (i = 0; i < 256; i = i + 1) begin
            db = done_cnt;
            load(i[7:0]);
            read_bits(i[7:0], 8, 101, -1, 8'h00, "byte 0..255");
            if (done_cnt - db !== 1) begin
                errors = errors + 1; $display("FAIL: byte %0d tx_done=%0d", i, done_cnt - db);
            end
        end

        // 4) SCLK cham ~2 MHz va ~1 MHz, gia tri ngau nhien
        for (i = 0; i < 40; i = i + 1) begin
            v = $random(seed);
            load(v);
            read_bits(v, 8, (i % 2) ? 253 : 501, -1, 8'h00, "ngau nhien SCLK cham");
        end

        // 5) Doc lai cung ket qua nhieu lan (khong send_en lai)
        load(8'h07);
        read_bits(8'h07, 8, 101, -1, 8'h00, "doc lan 1");
        read_bits(8'h07, 8, 101, -1, 8'h00, "doc lan 2 (khong send_en)");
        read_bits(8'h07, 8, 101, -1, 8'h00, "doc lan 3 (khong send_en)");

        // 6) Huy giua chung (3 bit) roi doc lai: phai ra lai tu MSB, khong tx_done
        load(8'hC9);
        db = done_cnt;
        read_bits(8'hC9, 3, 101, -1, 8'h00, "huy sau 3 bit");
        expect_done(db, 0, "huy giua chung khong tx_done");
        read_bits(8'hC9, 8, 101, -1, 8'h00, "doc day du sau khi huy");

        // 7) send_en den khi CS_N dang thap (giua bit 4): lan doc dang chay khong bi doi,
        //    byte moi dung cho lan sau
        load(8'hA6);
        read_bits(8'hA6, 8, 101, 3, 8'h5B, "send_en khi CS_N thap: lan dang chay giu nguyen");
        read_bits(8'h5B, 8, 101, -1, 8'h00, "lan sau nhan byte moi 0x5B");

        // 8) Reset giua chung
        load(8'hFF);
        @(negedge clk); rst = 1; repeat (4) @(negedge clk); rst = 0; repeat (4) @(negedge clk);
        read_bits(8'h00, 8, 101, -1, 8'h00, "sau reset lai doc 0x00");

        $display("---------------------------------------");
        $display("Do tre MISO sau canh xuong SCLK (RTL, chua tinh Tco/tre bang mach): min %0.1f ns, max %0.1f ns (%0d lan doi)",
                 min_dly, max_dly, dly_cnt);
        $display("=======================================");
        if (errors == 0) $display("PASS: spi_slave_tx, %0d nhom kiem tra, 0 loi", tests);
        else             $display("FAIL: spi_slave_tx, %0d loi / %0d nhom", errors, tests);
        $display("=======================================");
        $finish;
    end
endmodule
