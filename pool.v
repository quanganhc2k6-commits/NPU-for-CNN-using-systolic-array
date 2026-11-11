module pool (
    input  wire              clk,
    input  wire              rst,
    input  wire signed [7:0] data_in,
    input  wire              wr_en,
    input  wire        [7:0] row_size,   // 28 hoặc 10, phải là số chẵn
    input  wire              start,

    output reg  signed [7:0] data_out,
    output reg               data_valid,
    output reg               pool_done
);

    // 14 phần tử = 28/2, phần tử lớn nhất cần dùng
    reg signed [9:0] line_acc [0:13];

    reg [7:0] row_cnt, col_cnt;
    reg       busy;

    wire [6:0] k        = col_cnt[7:1];           // col / 2
    wire       row_odd  = row_cnt[0];
    wire       col_odd  = col_cnt[0];
    wire       last_col = (col_cnt == row_size - 8'd1);
    wire       last_row = (row_cnt == row_size - 8'd1);

    wire signed [9:0] pix_ext = {{2{data_in[7]}}, data_in};   // sign-extend
    wire signed [9:0] sum     = line_acc[k] + pix_ext;

    always @(posedge clk) begin
        if (rst) begin
            row_cnt    <= 8'd0;
            col_cnt    <= 8'd0;
            busy       <= 1'b0;
            data_out   <= 8'sd0;
            data_valid <= 1'b0;
            pool_done  <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            pool_done  <= 1'b0;

            if (start) begin
                row_cnt <= 8'd0;
                col_cnt <= 8'd0;
                busy    <= 1'b1;

            end else if (busy && wr_en) begin

                // ── Tích lũy / xuất kết quả ──
                if (!row_odd) begin
                    if (!col_odd) line_acc[k] <= pix_ext;   // pixel đầu cửa sổ
                    else          line_acc[k] <= sum;
                end else begin
                    if (!col_odd) line_acc[k] <= sum;
                    else begin                              // pixel cuối cửa sổ
                        data_out   <= sum[9:2];             // chia 4
                        data_valid <= 1'b1;
                        if (last_row && last_col) begin
                            pool_done <= 1'b1;
                            busy      <= 1'b0;
                        end
                    end
                end

                // ── Đếm vị trí ──
                if (last_col) begin
                    col_cnt <= 8'd0;
                    row_cnt <= row_cnt + 8'd1;
                end else begin
                    col_cnt <= col_cnt + 8'd1;
                end
            end
        end
    end

endmodule