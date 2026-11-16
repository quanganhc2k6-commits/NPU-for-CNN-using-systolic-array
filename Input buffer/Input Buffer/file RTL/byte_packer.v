module byte_packer #(
    parameter DATA_W = 16                
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              clr,         // xóa byte đang gom dở (frame_done)
    input  wire [7:0]        byte_in,     // <- spi_slave_rx.data_out
    input  wire              byte_en,     // <- spi_slave_rx.data_valid
    output reg  [DATA_W-1:0] word_out,
    output reg               word_valid   // xung 1 chu kỳ khi đủ 1 từ
);
    localparam BYTES = DATA_W / 8;

    reg  [DATA_W-1:0] shift;
    reg  [7:0]        byte_cnt;
    wire [DATA_W-1:0] new_word = (shift << 8) | byte_in;   // byte đến trước nằm ở bit cao

    always @(posedge clk) begin
        word_valid <= 1'b0;
        if (rst || clr) begin
            byte_cnt <= 8'd0;
            shift    <= {DATA_W{1'b0}};
        end else if (byte_en) begin
            shift <= new_word;
            if (byte_cnt == BYTES - 1) begin
                byte_cnt   <= 8'd0;
                word_out   <= new_word;
                word_valid <= 1'b1;
            end else
                byte_cnt <= byte_cnt + 8'd1;
        end
    end
endmodule