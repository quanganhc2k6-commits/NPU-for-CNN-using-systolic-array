module full_detect #(
    parameter DEPTH  = 65536,
    parameter ADDR_W = 16
)(
    input  wire            clk,
    input  wire            rst,
    input  wire            wr_en,
    input  wire [ADDR_W:0] wr_addr,
    output reg             buf_full       // xung 1 chu kỳ
);
    always @(posedge clk) begin
        if (rst) buf_full <= 1'b0;
        else     buf_full <= (wr_en && wr_addr == DEPTH - 1);
    end
endmodule