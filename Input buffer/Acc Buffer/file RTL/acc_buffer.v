// ============================================================
// acc_buffer.v
// Luu partial sum 32 bit (cong don) va output feature map giua cac layer.
// BRAM 2 cong dong bo, 1 clock: cong ghi va cong doc co dia chi rieng.
// Doc dong bo, tre 1 chu ky. Phep cong (doc - cong - ghi) lam ben ngoai.
// ============================================================
module acc_buffer #(
    parameter DEPTH  = 4704,   // 28*28*6 = feature map lon nhat cua LeNet-5
    parameter ADDR_W = 13,     // 12 bit chi goi duoc 4096 o, khong du cho 4704
    parameter DATA_W = 32
)(
    input  wire              clk,
    input  wire              rst,        // reset dong bo (chi xoa rd_data, khong xoa noi dung nho)
    input  wire [DATA_W-1:0] wr_data,    // partial sum, hoac activation 8 bit zero-extended
    input  wire [ADDR_W-1:0] wr_addr,
    input  wire              wr_en,
    input  wire [ADDR_W-1:0] rd_addr,
    input  wire              rd_en,
    output reg  [DATA_W-1:0] rd_data     // tre 1 chu ky; giu nguyen khi rd_en = 0
);
    (* ram_style = "block" *) reg [DATA_W-1:0] mem [0:DEPTH-1];

    // Khoi tao ve 0 luc cau hinh FPGA (BRAM khong tu xoa ve 0 giua cac khung anh)
    integer i;
    initial for (i = 0; i < DEPTH; i = i + 1) mem[i] = {DATA_W{1'b0}};

    always @(posedge clk) begin
        // Cong ghi: bo qua dia chi ngoai vung
        if (wr_en && (wr_addr < DEPTH))
            mem[wr_addr] <= wr_data;

        // Cong doc: doc dong bo, rd_en = 0 thi giu gia tri cu
        if (rst)
            rd_data <= {DATA_W{1'b0}};
        else if (rd_en)
            rd_data <= (rd_addr < DEPTH) ? mem[rd_addr] : {DATA_W{1'b0}};
    end
endmodule
