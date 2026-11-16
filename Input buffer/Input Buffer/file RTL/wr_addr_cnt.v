module wr_addr_cnt #(
    parameter DEPTH  = 65536,
    parameter ADDR_W = 16
)(
    input  wire          clk,
    input  wire          rst,
    input  wire          frame_done,
    input  wire          wr_en,
    output reg  [ADDR_W:0] wr_addr,       // rộng hơn 1 bit để chứa được giá trị DEPTH
    output wire          full             // mức 1 khi đã ghi đủ DEPTH từ
);
    assign full = (wr_addr == DEPTH);

    always @(posedge clk) begin
        if (rst || frame_done)
            wr_addr <= {(ADDR_W+1){1'b0}};
        else if (wr_en && !full)          // bão hòa ở DEPTH, không quay vòng
            wr_addr <= wr_addr + 1'b1;
    end
endmodule