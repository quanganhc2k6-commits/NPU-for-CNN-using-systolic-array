`timescale 1ns/1ps
module tb_acc_buffer;
    // Cau hinh nho de mo phong nhanh: DEPTH = 50, dia chi 6 bit nen 50..63 la ngoai vung
    localparam DEPTH = 50, ADDR_W = 6, DATA_W = 32;

    reg                clk = 0, rst = 1, wr_en = 0, rd_en = 0;
    reg  [DATA_W-1:0]  wr_data = 0;
    reg  [ADDR_W-1:0]  wr_addr = 0, rd_addr = 0;
    wire [DATA_W-1:0]  rd_data;
    integer i, errors = 0;

    acc_buffer #(.DEPTH(DEPTH), .ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
        .clk(clk), .rst(rst), .wr_data(wr_data), .wr_addr(wr_addr), .wr_en(wr_en),
        .rd_addr(rd_addr), .rd_en(rd_en), .rd_data(rd_data)
    );

    always #5 clk = ~clk;

    // Du lieu mau 32 bit (co ca gia tri co bit dau = 1)
    function [DATA_W-1:0] pat(input integer k);
        pat = k * 32'h01020305 + 32'h8000_0001;
    endfunction

    task tick; begin @(posedge clk); #1; end endtask

    task check(input [DATA_W-1:0] e, input [255:0] msg);
        begin
            if (rd_data !== e) begin
                errors = errors + 1;
                if (errors < 10)
                    $display("FAIL [%0s]: rd_data=%h, mong doi %h", msg, rd_data, e);
            end
        end
    endtask

    task write_word(input [ADDR_W-1:0] a, input [DATA_W-1:0] d);
        begin wr_en = 1; wr_addr = a; wr_data = d; tick; wr_en = 0; end
    endtask

    // Doc 1 o: sau tick, rd_data da co du lieu (tre 1 chu ky)
    task read_word(input [ADDR_W-1:0] a);
        begin rd_en = 1; rd_addr = a; tick; rd_en = 0; end
    endtask

    // Cong don: doc o cu, cong them delta, ghi lai cung dia chi
    task accumulate(input [ADDR_W-1:0] a, input [DATA_W-1:0] delta);
        begin
            read_word(a);
            wr_en = 1; wr_addr = a; wr_data = rd_data + delta; tick; wr_en = 0;
        end
    endtask

    initial begin
        // 1) Reset: rd_data ve 0
        tick; tick;
        check(32'h0, "reset");
        rst = 0;

        // 2) Ghi lien tuc DEPTH o, roi doc lien tuc moi chu ky 1 dia chi
        for (i = 0; i < DEPTH; i = i + 1) begin
            wr_en = 1; wr_addr = i; wr_data = pat(i); tick;
        end
        wr_en = 0;

        rd_en = 1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            rd_addr = i;
            if (i > 0) check(pat(i - 1), "tre 1 chu ky");   // truoc canh clock van la du lieu cu
            tick;
            check(pat(i), "doc lien tuc");
        end
        rd_en = 0;

        // 3) rd_en = 0: rd_data giu nguyen du rd_addr doi
        read_word(7);
        check(pat(7), "doc o 7");
        rd_addr = 8; tick; tick;
        check(pat(7), "rd_en=0 giu gia tri");

        // 4) wr_en = 0: khong ghi du wr_addr, wr_data thay doi
        for (i = 0; i < DEPTH; i = i + 1) begin
            wr_en = 0; wr_addr = i; wr_data = ~pat(i); tick;
        end
        for (i = 0; i < DEPTH; i = i + 1) begin
            read_word(i);
            check(pat(i), "wr_en=0 khong ghi de");
        end

        // 5) Cong don 3 luot vao dia chi 5: 120, -45, +30 -> 105
        write_word(5, 32'd120);
        accumulate(5, 32'd0 - 32'd45);
        accumulate(5, 32'd30);
        read_word(5);
        check(32'd105, "cong don 120-45+30");

        //    So am luu dang bu hai 32 bit: 0 + (-45) = 0xFFFFFFD3
        write_word(6, 32'd0);
        accumulate(6, 32'd0 - 32'd45);
        read_word(6);
        check(32'hFFFFFFD3, "so am -45");
        if ($signed(rd_data) !== -45) begin
            errors = errors + 1;
            $display("FAIL [co dau]: rd_data=%0d, mong doi -45", $signed(rd_data));
        end

        // 6) Ghi va doc cung dia chi trong cung chu ky: doc nhan gia tri cu
        write_word(9, 32'd111);
        wr_en = 1; wr_addr = 9; wr_data = 32'd222;
        rd_en = 1; rd_addr = 9; tick;
        wr_en = 0; rd_en = 0;
        check(32'd111, "doc truoc ghi cung chu ky");
        read_word(9);
        check(32'd222, "doc sau khi ghi xong");

        // 7) Ngoai vung (dia chi 55 >= DEPTH): ghi bi bo qua, doc tra ve 0
        write_word(10, 32'h0000_1234);
        write_word(55, 32'hDEAD_BEEF);
        read_word(10);
        check(32'h0000_1234, "o 10 khong bi anh huong");
        read_word(55);
        check(32'h0, "doc ngoai vung");

        // 8) Activation 8 bit zero-extended: 0x15 = 21
        write_word(20, 32'h0000_0015);
        read_word(20);
        check(32'h0000_0015, "activation zero-extend");
        if (rd_data[7:0] !== 8'h15 || rd_data[31:8] !== 24'h0) begin
            errors = errors + 1;
            $display("FAIL [zero-extend]: rd_data=%h", rd_data);
        end

        // 9) rst chi xoa rd_data, noi dung nho van con
        rst = 1; tick; rst = 0;
        check(32'h0, "rst xoa rd_data");
        read_word(20);
        check(32'h0000_0015, "rst khong xoa noi dung");

        if (errors == 0) $display("PASS: tb_acc_buffer");
        else             $display("FAIL: %0d loi", errors);
        $finish;
    end

    initial begin
        #2_000_000;
        $display("FAIL: timeout");
        $finish;
    end
endmodule