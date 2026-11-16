`timescale 1ns / 1ps
// Testbench tu kiem tra cho spi_slave_rx (SPI Mode 0, clk 50 MHz)
// SCLK dung do tre tinh bang ns, khong boi so cua chu ky clk (20 ns)
// => pha giua SCLK va clk troi dan, quet qua nhieu vi tri tuong doi.
module tb_spi_slave_rx;

    reg        clk = 0;
    reg        rst = 1;
    reg        SCLK = 0;
    reg        MOSI = 0;
    reg        CS_N = 1;
    wire [7:0] data_out;
    wire       data_valid;
    wire       frame_done;

    spi_slave_rx #(.NUM_BYTES(784)) dut (
        .clk(clk), .rst(rst), .SCLK(SCLK), .MOSI(MOSI), .CS_N(CS_N),
        .data_out(data_out), .data_valid(data_valid), .frame_done(frame_done));

    always #10 clk = ~clk;                   // 50 MHz

    reg [7:0] sent [0:2047];                 // byte master da gui
    reg [7:0] got  [0:16383];                 // byte slave nhan duoc
    integer   rx_cnt = 0;                    // tong so data_valid
    integer   fd_cnt = 0;                    // tong so frame_done
    integer   fd_pos [0:255];                // vi tri (so byte tich luy) cua tung frame_done
    integer   errors = 0;
    integer   tests  = 0;
    integer   seed   = 32'h1234_5678;

    // Do tre tu canh len SCLK thu 8 cua byte den luc data_valid len 1 (RTL, chua tinh tre mach)
    realtime rise_t   = 0;
    realtime lat_min  = 1e9;
    realtime lat_max  = 0;
    always @(posedge SCLK) rise_t = $realtime;

    always @(posedge clk) begin
        if (data_valid) begin
            got[rx_cnt] = data_out;
            rx_cnt = rx_cnt + 1;
            if ($realtime - rise_t < lat_min) lat_min = $realtime - rise_t;
            if ($realtime - rise_t > lat_max) lat_max = $realtime - rise_t;
        end
        if (frame_done) begin
            fd_pos[fd_cnt] = rx_cnt;          // so byte da nhan tai thoi diem frame_done
            fd_cnt = fd_cnt + 1;
            if (!data_valid) begin
                errors = errors + 1;
                $display("FAIL: frame_done khong cung cycle voi data_valid");
            end
        end
    end

    // Gui nbits bit cua b (MSB truoc), doi MOSI o canh xuong, lay mau o canh len
    task spi_bits(input [7:0] b, input integer nbits, input integer half);
        integer i;
        begin
            for (i = 0; i < nbits; i = i + 1) begin
                MOSI = b[7 - i];
                #(half);  SCLK = 1;
                #(half);  SCLK = 0;
            end
        end
    endtask

    // Gui n byte ngau nhien. gap_max > 0: chen khoang lang ngau nhien giua cac byte
    task send_bytes(input integer base, input integer n, input integer half,
                    input integer gap_max);
        integer i, g;
        begin
            for (i = 0; i < n; i = i + 1) begin
                sent[base + i] = $random(seed);
                spi_bits(sent[base + i], 8, half);
                if (gap_max > 0) begin
                    g = $random(seed) & 32'h7fff_ffff;
                    #(g % gap_max);
                end
            end
        end
    endtask

    task cs_low;  begin #200; CS_N = 0; #200; end endtask
    task cs_high; begin #200; CS_N = 1; #400; end endtask

    // So sanh got[rx_base ..] voi sent[0 ..] n byte
    task check(input integer rx_base, input integer n, input integer exp_fd,
               input integer fd_base, input [255:0] name);
        integer i, j, e;
        begin
            e = 0;
            tests = tests + 1;
            if (rx_cnt - rx_base !== n) begin
                e = e + 1;
                $display("FAIL [%0s]: nhan %0d byte, can %0d", name, rx_cnt - rx_base, n);
            end
            for (i = 0; i < n; i = i + 1)
                if (got[rx_base + i] !== sent[i]) begin
                    e = e + 1;
                    if (e < 6) $display("FAIL [%0s]: byte %0d nhan %02h, gui %02h",
                                        name, i, got[rx_base + i], sent[i]);
                end
            if (fd_cnt - fd_base !== exp_fd) begin
                e = e + 1;
                $display("FAIL [%0s]: frame_done %0d lan, can %0d", name, fd_cnt - fd_base, exp_fd);
            end else begin
                // frame_done thu j phai xuat hien dung luc nhan byte thu 784*(j+1) cua nhom
                for (j = 0; j < exp_fd; j = j + 1)
                    if (fd_pos[fd_base + j] - rx_base !== 784 * (j + 1)) begin
                        e = e + 1;
                        $display("FAIL [%0s]: frame_done #%0d o byte %0d, can %0d", name, j,
                                 fd_pos[fd_base + j] - rx_base, 784 * (j + 1));
                    end
            end
            errors = errors + e;
            if (e == 0) $display("PASS [%0s]: %0d byte, %0d frame_done", name, n, exp_fd);
        end
    endtask

    integer rb, fb;
    initial begin
        repeat (6) @(negedge clk);
        rst = 0;
        repeat (4) @(negedge clk);

        // 1) Frame 784 byte, SCLK ~4.95 MHz (half = 101 ns), khong khoang lang
        rb = rx_cnt; fb = fd_cnt;
        cs_low; send_bytes(0, 784, 101, 0); cs_high;
        check(rb, 784, 1, fb, "frame 784B, 4.95 MHz");

        // 2) Frame 784 byte, SCLK ~2 MHz (half = 253 ns), co khoang lang ngau nhien
        rb = rx_cnt; fb = fd_cnt;
        cs_low; send_bytes(0, 784, 253, 700); cs_high;
        check(rb, 784, 1, fb, "frame 784B, 2 MHz + khoang lang");

        // 3) Huy frame giua chung (100 byte) roi gui frame day du
        rb = rx_cnt; fb = fd_cnt;
        cs_low; send_bytes(0, 100, 101, 0); cs_high;
        check(rb, 100, 0, fb, "huy sau 100 byte");
        rb = rx_cnt; fb = fd_cnt;
        cs_low; send_bytes(0, 784, 137, 0); cs_high;
        check(rb, 784, 1, fb, "frame day du sau khi huy");

        // 4) Huy giua 1 byte (chi 3 bit) -> bo dem bit phai duoc xoa
        rb = rx_cnt; fb = fd_cnt;
        cs_low; spi_bits(8'hA5, 3, 101); cs_high;
        check(rb, 0, 0, fb, "huy giua byte (3 bit)");
        rb = rx_cnt; fb = fd_cnt;
        cs_low; send_bytes(0, 784, 101, 0); cs_high;
        check(rb, 784, 1, fb, "frame sau khi huy giua byte");

        // 5) 2 frame lien tiep khi CS_N van thap (1568 byte) -> 2 frame_done
        rb = rx_cnt; fb = fd_cnt;
        cs_low; send_bytes(0, 1568, 101, 0); cs_high;
        check(rb, 1568, 2, fb, "1568 byte 1 lan CS_N thap");

        // 6) Mau du lieu bien: toan 00, toan FF, xen ke AA/55
        begin : edge_patterns
            integer p, i;
            for (p = 0; p < 3; p = p + 1) begin
                rb = rx_cnt; fb = fd_cnt;
                cs_low;
                for (i = 0; i < 784; i = i + 1) begin
                    sent[i] = (p == 0) ? 8'h00 : (p == 1) ? 8'hFF : (i[0] ? 8'h55 : 8'hAA);
                    spi_bits(sent[i], 8, 101);
                end
                cs_high;
                check(rb, 784, 1, fb, (p == 0) ? "toan 00" : (p == 1) ? "toan FF" : "xen ke AA/55");
            end
        end

        $display("---------------------------------------");
        $display("Tong: %0d byte, %0d frame_done. Tre canh len SCLK thu 8 -> data_valid: min %0.1f ns, max %0.1f ns",
                 rx_cnt, fd_cnt, lat_min, lat_max);
        $display("=======================================");
        if (errors == 0) $display("PASS: spi_slave_rx, %0d nhom kiem tra, 0 loi", tests);
        else             $display("FAIL: spi_slave_rx, %0d loi / %0d nhom", errors, tests);
        $display("=======================================");
        $finish;
    end
endmodule
