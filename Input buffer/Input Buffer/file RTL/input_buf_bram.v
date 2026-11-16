module input_buf_bram #(
    parameter DEPTH   = 65536,
    parameter ADDR_W  = 16,               // = $clog2(DEPTH)
    parameter DATA_W  = 16,
    parameter OUT_REG = 0                 // 1: thêm thanh ghi đầu ra (độ trễ đọc 2 chu kỳ)
)(
    input  wire              clk,
    input  wire              we,
    input  wire [ADDR_W-1:0] wr_addr,
    input  wire [DATA_W-1:0] wr_data,
    input  wire [ADDR_W-1:0] rd_addr,
    output wire [DATA_W-1:0] rd_data
);
    (* ram_style = "block" *) reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [DATA_W-1:0] rd_raw, rd_q;

    always @(posedge clk) begin
        if (we) mem[wr_addr] <= wr_data;
        rd_raw <= mem[rd_addr];           // đọc đồng bộ
        rd_q   <= rd_raw;                 // tầng đệm tùy chọn
    end

    assign rd_data = OUT_REG ? rd_q : rd_raw;
endmodule