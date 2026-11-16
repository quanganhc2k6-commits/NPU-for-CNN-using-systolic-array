`timescale 1ns / 1ps
//==============================================================================
// argmax.v
// Tim index cua score lon nhat trong 10 score INT8 (signed) gui tuan tu.
//
//  - start       : pulse, bat dau phep so sanh moi (reset bo dem)
//  - score_valid : pulse moi khi score_in hop le (10 lan / 1 anh)
//  - valid_out   : pulse 1 cycle, cung luc class_out cap nhat (sau score thu 10)
//  - class_out   : giu nguyen den khi co ket qua moi
//
// Quy uoc: neu nhieu score bang nhau -> chon index NHO nhat (so sanh strict >).
// Score dau tien (cnt == 0) luon duoc nhan, nen khong can khoi tao max_val = -128.
// Neu start va score_valid xay ra cung 1 cycle, score do duoc tinh la score dau.
//==============================================================================
module argmax (
    input  wire              clk,
    input  wire              rst,          // reset dong bo, active high
    input  wire signed [7:0] score_in,     // 1 score INT8 / cycle
    input  wire              score_valid,
    input  wire              start,
    output reg  [3:0]        class_out,    // 0..9
    output reg               valid_out
);

    localparam [3:0] LAST = 4'd9;          // so score - 1

    reg signed [7:0] max_val;
    reg        [3:0] max_idx;
    reg        [3:0] cnt;                  // so score da nhan (0..9)

    // cnt hieu dung: start co uu tien reset bo dem
    wire [3:0] cnt_eff = start ? 4'd0 : cnt;

    // Score hien tai thang neu la score dau, hoac lon hon max (signed, strict)
    wire take = (cnt_eff == 4'd0) || (score_in > max_val);

    always @(posedge clk) begin
        if (rst) begin
            max_val   <= 8'sd0;
            max_idx   <= 4'd0;
            cnt       <= 4'd0;
            class_out <= 4'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;             // mac dinh: pulse 1 cycle

            if (start)
                cnt <= 4'd0;

            if (score_valid) begin
                if (take) begin
                    max_val <= score_in;
                    max_idx <= cnt_eff;
                end

                if (cnt_eff == LAST) begin
                    // Score thu 10: chot ket qua (da gom ca score hien tai)
                    class_out <= take ? cnt_eff : max_idx;
                    valid_out <= 1'b1;
                    cnt       <= 4'd0;     // san sang cho frame ke tiep
                end else begin
                    cnt <= cnt_eff + 4'd1;
                end
            end
        end
    end

endmodule
