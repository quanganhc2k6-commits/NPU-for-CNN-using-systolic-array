module post_proc (
    input  wire               clk,
    input  wire               rst,
    input  wire signed [31:0] acc_in,
    input  wire        [7:0]  scale,      // unsigned, giữ cố định trong 1 layer
    input  wire        [3:0]  shift,
    input  wire               valid_in,

    output reg  signed [7:0]  result_out,
    output reg                valid_out
);

    // ─── Stage 1: ReLU ────────────────────────────────
    reg [30:0] relu_s1;
    reg [7:0]  scale_s1;
    reg [3:0]  shift_s1;
    reg        v_s1;

    always @(posedge clk) begin
        if (rst) begin
            relu_s1  <= 31'd0;
            scale_s1 <= 8'd0;
            shift_s1 <= 4'd0;
            v_s1     <= 1'b0;
        end else begin
            relu_s1  <= acc_in[31] ? 31'd0 : acc_in[30:0];  // bit 31 = dấu
            scale_s1 <= scale;
            shift_s1 <= shift;
            v_s1     <= valid_in;
        end
    end

    // ─── Stage 2: Multiply ────────────────────────────
    reg [38:0] mult_s2;
    reg [3:0]  shift_s2;
    reg        v_s2;

    always @(posedge clk) begin
        if (rst) begin
            mult_s2  <= 39'd0;
            shift_s2 <= 4'd0;
            v_s2     <= 1'b0;
        end else begin
            mult_s2  <= relu_s1 * scale_s1;   // cả 2 đều unsigned
            shift_s2 <= shift_s1;
            v_s2     <= v_s1;
        end
    end

    // ─── Stage 3: Shift + Clamp ───────────────────────
    wire [38:0] shifted = mult_s2 >> shift_s2;

    always @(posedge clk) begin
        if (rst) begin
            result_out <= 8'sd0;
            valid_out  <= 1'b0;
        end else begin
            result_out <= (shifted > 39'd127) ? 8'sd127 : shifted[7:0];
            valid_out  <= v_s2;
        end
    end

endmodule