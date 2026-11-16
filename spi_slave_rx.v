`timescale 1ns / 1ps
//==============================================================================
// Module   : spi_slave_rx
// Mo ta    : SPI slave (Mode 0) nhan NUM_BYTES byte (mac dinh 784 = 1 anh MNIST)
//            tu ESP32. Moi byte nhan xong -> data_valid pulse 1 cycle clk.
//            Du NUM_BYTES byte -> frame_done pulse (cung cycle voi data_valid
//            cua byte cuoi).
//
// Cong:
//   clk        IN   system clock (50 MHz)
//   rst        IN   reset dong bo, active high
//   SCLK       IN   SPI clock tu ESP32 (BAT DONG BO voi clk)
//   MOSI       IN   data tu ESP32
//   CS_N       IN   chip select, active low (low = dang trong frame)
//   data_out   OUT  [7:0] byte vua nhan, giu den byte ke tiep
//   data_valid OUT  pulse 1 cycle khi data_out hop le
//   frame_done OUT  pulse 1 cycle khi da nhan du NUM_BYTES byte
//
// Quy uoc  : SPI Mode 0 (CPOL=0, CPHA=0): lay mau MOSI o canh LEN cua SCLK,
//            MSB truoc. CS_N len cao -> huy frame (xoa bo dem bit va byte).
// Gioi han : SCLK duoc lay mau bang clk qua bo dong bo 2 FF + bo phat hien canh,
//            nen moi nua chu ky SCLK phai dai it nhat vai chu ky clk. Mo phong ly
//            tuong: dung toi 25 MHz (sat gioi han Nyquist), sai o 33 MHz. Khuyen
//            nghi thuc te: SCLK <= clk/5 (10 MHz) cho rieng rx; voi he thong co
//            spi_slave_tx dung chung SCLK thi gioi han la 5 MHz (xem spi_slave_tx).
//==============================================================================
module spi_slave_rx #(
    parameter NUM_BYTES = 784
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       SCLK,
    input  wire       MOSI,
    input  wire       CS_N,
    output reg  [7:0] data_out,
    output reg        data_valid,
    output reg        frame_done
);

    // ---- Dong bo 2 FF (synchronizer) cho 3 tin hieu tu mien clock khac ------
    // Khong reset cac FF dong bo (tranh anh huong metastability); rst phai
    // giu >= 3 cycle de chung duoc xoa sach X khi mo phong.
    reg [1:0] sclk_sync;
    reg [1:0] mosi_sync;
    reg [1:0] cs_sync;
    reg       sclk_prev;                  // gia tri sclk dong bo o cycle truoc

    always @(posedge clk) begin
        sclk_sync <= {sclk_sync[0], SCLK};
        mosi_sync <= {mosi_sync[0], MOSI};
        cs_sync   <= {cs_sync[0],   CS_N};
        sclk_prev <= sclk_sync[1];
    end

    wire sclk_s    = sclk_sync[1];
    wire mosi_s    = mosi_sync[1];        // cung do tre voi sclk_s => thang hang
    wire cs_s      = cs_sync[1];
    wire sclk_rise = sclk_s & ~sclk_prev; // canh len SCLK (1 cycle clk)

    // ---- Thanh ghi dich va bo dem -------------------------------------------
    reg [7:0]  shift;                     // gom cac bit da nhan cua byte hien tai
    reg [2:0]  bit_cnt;                   // so bit da nhan (0..7)
    reg [15:0] byte_cnt;                  // so byte da nhan trong frame

    always @(posedge clk) begin
        if (rst) begin
            shift      <= 8'd0;
            bit_cnt    <= 3'd0;
            byte_cnt   <= 16'd0;
            data_out   <= 8'd0;
            data_valid <= 1'b0;
            frame_done <= 1'b0;
        end else begin
            data_valid <= 1'b0;           // mac dinh: pulse 1 cycle
            frame_done <= 1'b0;

            if (cs_s) begin
                // CS_N cao: ngoai frame hoac huy frame -> xoa bo dem
                bit_cnt  <= 3'd0;
                byte_cnt <= 16'd0;
            end else if (sclk_rise) begin
                shift <= {shift[6:0], mosi_s};          // dich MSB truoc

                if (bit_cnt == 3'd7) begin
                    // bit thu 8: byte day du = {7 bit cu, bit vua nhan}
                    data_out   <= {shift[6:0], mosi_s};
                    data_valid <= 1'b1;
                    bit_cnt    <= 3'd0;

                    if (byte_cnt == NUM_BYTES - 1) begin
                        frame_done <= 1'b1;             // du 784 byte
                        byte_cnt   <= 16'd0;
                    end else begin
                        byte_cnt   <= byte_cnt + 16'd1;
                    end
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
