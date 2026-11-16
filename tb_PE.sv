module tb_PE();
//input
reg clk;
reg rst;
reg en;
reg load_weight;
reg signed [7:0] act_in;
reg signed [31:0] psum_in;
reg signed [7:0] weight_in;
//output
wire signed [31:0] psum_out;
// nối DUT
PE dut(
    .clk(clk),
    .rst(rst),
    .en(en),
    .load_weight(load_weight),
    .act_in(act_in),
    .psum_in(psum_in),
    .psum_out(psum_out),
    .weight_in(weight_in)
);
parameter period_clk = 10;
initial begin
    clk = 0;
forever #(period_clk/2) clk = ~clk;
end
initial begin
    // bật rst = 1 và khời tại các giá trị ban đầu
    rst = 1;
    en = 0;
    load_weight = 0;
    act_in = 0;
    weight_in = 0;
    psum_in = 0;
   // delay chờ ổn định
    #20
    //cho rst = 0 chuẩn bị chạy
    rst = 0;
end
initial begin
    weight_in = 8'sd5;
    @(posedge clk);
    load_weight = 1;
    @(posedge clk);
    load_weight = 0;
    en = 1;
    act_in = 8'sd2;
    psum_in = 32'sd10;
    @(posedge clk);
    #1
    $display("Test 1 psum_out = %d [Expected: 20]", psum_out);
    act_in = 8'sd3;
    psum_in = 32'sd20;
    @(posedge clk);
    #1
     $display("Test 2 psum_out = %d [Expected: 45]", psum_out);
    en = 0;
    act_in = 8'sd4;
    psum_in = 32'sd45;
    @(posedge clk);
    #1
    $display("Test 3(en = 1) psum_out = %d [Expected: 45]", psum_out);
end
endmodule
