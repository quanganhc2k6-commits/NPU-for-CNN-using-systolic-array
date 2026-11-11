module pe (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire        load_weight,

    input  wire signed [7:0]  weight_in,
    input  wire signed [7:0]  act_in,
    input  wire signed [31:0] psum_in,

    output reg  signed [31:0] psum_out
);

    // ─── Internal wires ───────────────────────────────
    reg  signed [7:0]  weight_reg;   // giữ weight cố định (Weight Stationary)
    wire signed [15:0] product;      // kết quả nhân 8×8 → 16-bit
    wire signed [31:0] product_32;   // sign-extend lên 32-bit

    // ─── Load weight ──────────────────────────────────
    // Chỉ cập nhật weight khi load_weight = 1
    // Sau đó giữ cố định trong suốt quá trình tính layer
    always @(posedge clk) begin
        if (rst)
            weight_reg <= 8'sd0;
        else if (load_weight)
            weight_reg <= weight_in;
    end

    // ─── Multiply ─────────────────────────────────────
    assign product    = weight_reg * act_in;
    assign product_32 = {{16{product[15]}}, product};  // sign-extend

    // ─── Accumulate (pipeline register) ───────────────
    // en = 1 → tính và lưu kết quả
    // en = 0 → giữ nguyên psum_out (không ghi đè)
    always @(posedge clk) begin
        if (rst)
            psum_out <= 32'sd0;
        else if (en)
            psum_out <= psum_in + product_32;
    end

endmodule