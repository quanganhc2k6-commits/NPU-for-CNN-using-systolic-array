module weight_rom #(
    // File .mem (hex, 1 byte/dong, theo thu tu Conv1,Conv2,FC1,FC2,FC3).
    // De trong: dung du lieu mau (i*37+11) de mo phong.
    parameter INIT_FILE = ""
)(
    input  wire              clk,
    input  wire [2:0]        layer_sel,   // 0=Conv1, 1=Conv2, 2=FC1, 3=FC2, 4=FC3
    input  wire [15:0]       rd_addr,     // dia chi weight trong layer dang chon
    output reg  signed [7:0] weight_out   // weight INT8 co dau, tre 1 chu ky
);
    localparam TOTAL = 61470;
 
    localparam [15:0] BASE_CONV1 = 16'd0,     SIZE_CONV1 = 16'd150;
    localparam [15:0] BASE_CONV2 = 16'd150,   SIZE_CONV2 = 16'd2400;
    localparam [15:0] BASE_FC1   = 16'd2550,  SIZE_FC1   = 16'd48000;
    localparam [15:0] BASE_FC2   = 16'd50550, SIZE_FC2   = 16'd10080;
    localparam [15:0] BASE_FC3   = 16'd60630, SIZE_FC3   = 16'd840;
 
    // Bang dia chi dau vung va kich thuoc theo layer_sel
    reg [15:0] base, size;
    reg        layer_ok;
    always @* begin
        layer_ok = 1'b1;
        case (layer_sel)
            3'd0:    begin base = BASE_CONV1; size = SIZE_CONV1; end
            3'd1:    begin base = BASE_CONV2; size = SIZE_CONV2; end
            3'd2:    begin base = BASE_FC1;   size = SIZE_FC1;   end
            3'd3:    begin base = BASE_FC2;   size = SIZE_FC2;   end
            3'd4:    begin base = BASE_FC3;   size = SIZE_FC3;   end
            default: begin base = 16'd0;      size = 16'd0; layer_ok = 1'b0; end
        endcase
    end
 
    wire        in_range = layer_ok && (rd_addr < size);
    wire [15:0] abs_addr = base + rd_addr;   // chi dung khi in_range = 1 (<= 61469, khong tran)
 
    // ROM: khong co cong ghi, noi dung nap luc khoi tao
    (* rom_style = "block" *) reg [7:0] rom [0:TOTAL-1];
    integer i;
    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, rom);
        else for (i = 0; i < TOTAL; i = i + 1) rom[i] = i * 37 + 11;
    end
 
    // Doc dong bo: dia chi vao chu ky nay, weight ra chu ky sau
    always @(posedge clk) begin
        if (in_range) weight_out <= rom[abs_addr];
        else          weight_out <= 8'sd0;     // layer_sel 5..7 hoac rd_addr vuot vung layer
    end
endmodule