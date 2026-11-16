`timescale 1ns/1ps
module tb_weight_rom;
    reg               clk = 0;
    reg  [2:0]        layer_sel = 0;
    reg  [15:0]       rd_addr = 0;
    wire signed [7:0] weight_out;
    integer errors = 0, k, l;
 
    weight_rom dut (.clk(clk), .layer_sel(layer_sel),
                    .rd_addr(rd_addr), .weight_out(weight_out));
 
    always #5 clk = ~clk;
 
    // Bang dia chi dau vung va kich thuoc (viet doc lap voi DUT)
    function integer base_of(input integer lyr);
        case (lyr)
            0: base_of = 0;
            1: base_of = 150;
            2: base_of = 2550;
            3: base_of = 50550;
            default: base_of = 60630;
        endcase
    endfunction
 
    function integer size_of(input integer lyr);
        case (lyr)
            0: size_of = 150;
            1: size_of = 2400;
            2: size_of = 48000;
            3: size_of = 10080;
            default: size_of = 840;
        endcase
    endfunction
 
    // Du lieu mau trong ROM tai dia chi tuyet doi a
    function [7:0] exp_w(input integer a);
        exp_w = a * 37 + 11;
    endfunction
 
    // Doi 1 canh clock roi tre them 1 ns de lay mau ket qua
    task tick; begin @(posedge clk); #1; end endtask
 
    task check(input [7:0] e, input integer lyr, input integer a, input [255:0] msg);
        begin
            if (weight_out !== e) begin
                errors = errors + 1;
                if (errors < 10)
                    $display("FAIL [%0s]: layer=%0d addr=%0d weight_out=%h, mong doi %h",
                             msg, lyr, a, weight_out, e);
            end
        end
    endtask
 
    // Quet toan bo 1 layer, moi chu ky 1 dia chi
    task sweep(input integer lyr);
        integer a;
        begin
            for (a = 0; a < size_of(lyr); a = a + 1) begin
                layer_sel = lyr; rd_addr = a;
                // Truoc canh clock, ngo ra van la du lieu cua dia chi truoc (doc dong bo)
                if (a > 0) check(exp_w(base_of(lyr) + a - 1), lyr, a, "tre 1 chu ky");
                tick;
                check(exp_w(base_of(lyr) + a), lyr, a, "quet layer");
            end
        end
    endtask
 
    initial begin
        tick; tick;
 
        // 1) Quet day du 5 layer: kiem tra ban do dia chi, du lieu, do tre 1 chu ky
        for (l = 0; l < 5; l = l + 1) sweep(l);
 
        // 2) Doi layer lien tuc moi chu ky (layer_sel + rd_addr doi cung luc)
        for (k = 0; k < 5000; k = k + 1) begin
            l = k % 5;
            layer_sel = l; rd_addr = (k * 7919) % size_of(l);
            tick;
            check(exp_w(base_of(l) + ((k * 7919) % size_of(l))), l, (k * 7919) % size_of(l), "doi layer");
        end
 
        // 3) Ngoai vung: rd_addr >= kich thuoc layer, hoac layer_sel 5..7, phai tra ve 0
        for (l = 0; l < 5; l = l + 1) begin
            layer_sel = l; rd_addr = size_of(l);        tick; check(8'h00, l, size_of(l), "ngoai vung");
            layer_sel = l; rd_addr = size_of(l) + 100;  tick; check(8'h00, l, size_of(l) + 100, "ngoai vung");
            layer_sel = l; rd_addr = 16'hFFFF;          tick; check(8'h00, l, 65535, "ngoai vung");
        end
        for (l = 5; l < 8; l = l + 1) begin
            layer_sel = l; rd_addr = 0;  tick; check(8'h00, l, 0,  "layer_sel sai");
            layer_sel = l; rd_addr = 10; tick; check(8'h00, l, 10, "layer_sel sai");
        end
 
        // 4) Weight la so co dau: Conv1 dia chi 4 co gia tri 0x9F = -97
        layer_sel = 0; rd_addr = 4; tick;
        check(8'h9F, 0, 4, "gia tri");
        if (!(weight_out < 0) || weight_out !== -8'sd97) begin
            errors = errors + 1;
            $display("FAIL [co dau]: weight_out=%0d, mong doi -97", weight_out);
        end
 
        if (errors == 0) $display("PASS: tb_weight_rom");
        else             $display("FAIL: %0d loi", errors);
        $finish;
    end
 
    initial begin
        #5_000_000;
        $display("FAIL: timeout");
        $finish;
    end
endmodule 