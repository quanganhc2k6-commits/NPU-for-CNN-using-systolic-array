module pe_array (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire        load_weight,

    // 4 weights — mỗi hàng 1 weight
    input  wire signed [7:0] weight_in [0:3],

    // 4 activations — mỗi cột 1 activation
    input  wire signed [7:0] act_in [0:3],

    // 4 partial sum output — từ hàng cuối mỗi cột
    output wire signed [31:0] psum_out [0:3],
    output reg                array_valid
);

    // ─── Internal psum wires ──────────────────────────
    // psum_wire[row][col] = psum_out của PE tại [row][col]
    wire signed [31:0] psum_wire [0:3][0:3];

    // ─── Generate 4×4 PE array ────────────────────────
    genvar row, col;
    generate
        for (row = 0; row < 4; row = row + 1) begin : gen_row
            for (col = 0; col < 4; col = col + 1) begin : gen_col // nhãn để đặt tên
                pe u_pe (
                    .clk         (clk),
                    .rst         (rst),
                    .en          (en),
                    .load_weight (load_weight),

                    // weight: tất cả PE cùng hàng nhận cùng weight
                    .weight_in   (weight_in[row]),

                    // activation: tất cả PE cùng cột nhận cùng activation
                    .act_in      (act_in[col]),

                    // psum_in:
                    //   hàng 0 → nhận 0 (bắt đầu tích lũy)
                    //   hàng 1,2,3 → nhận psum_out của PE hàng trên
                    .psum_in     (row == 0 ? 32'sd0 : psum_wire[row-1][col]),

                    .psum_out    (psum_wire[row][col])
                );
            end
        end
    endgenerate

    // 4 output từ 4 hàng cuối của mảng
    assign psum_out[0] = psum_wire[3][0];
    assign psum_out[1] = psum_wire[3][1];
    assign psum_out[2] = psum_wire[3][2];
    assign psum_out[3] = psum_wire[3][3];

  // delay 1 chu kì và là cờ báo với khối sau có data đúng
    always @(posedge clk) begin
        if (rst)
            array_valid <= 1'b0;
        else
            array_valid <= en;
    end

endmodule