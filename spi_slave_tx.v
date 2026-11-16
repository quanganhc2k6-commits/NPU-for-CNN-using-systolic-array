`timescale 1ns / 1ps
//==============================================================================
// Module   : spi_slave_tx
// Mo ta    : SPI slave (Mode 0) gui 1 byte ket qua (class 0..9) ve ESP32
//            tren duong MISO, MSB truoc.
//
// Cong:
//   clk      IN   system clock (50 MHz)
//   rst      IN   reset dong bo, active high
//   SCLK     IN   SPI clock tu ESP32 (BAT DONG BO voi clk)
//   CS_N     IN   chip select, active low
//   data_in  IN   [7:0] byte can gui (tu argmax.class_out, 4 bit thap)
//   send_en  IN   pulse "co data can gui"; data_in phai on dinh khi pulse
//   MISO     OUT  data noi tiep ve ESP32
//   tx_done  OUT  pulse 1 cycle khi da gui xong 8 bit
//
// Quy uoc  : SPI Mode 0: bit dau (MSB) da co san tren MISO TRUOC canh len SCLK
//            dau tien; MISO doi gia tri o canh XUONG cua SCLK.
//            send_en nen den khi CS_N dang cao. Byte duoc chot vao tx_hold va
//            giu nguyen den lan send_en ke tiep (doc lai nhieu lan van dung).
//            Neu CS_N len cao giua chung (huy), byte duoc nap lai tu dau.
// Gioi han : SCLK <= clk/10 (50 MHz -> toi da 5 MHz): MISO doi sau canh xuong
//            SCLK khoang 3 cycle clk (bo dong bo 2 FF + 1 FF dau ra).
//==============================================================================
module spi_slave_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire       SCLK,
    input  wire       CS_N,
    input  wire [7:0] data_in,
    input  wire       send_en,
    output reg        MISO,
    output reg        tx_done
);

    // ---- Dong bo 2 FF cho SCLK va CS_N --------------------------------------
    reg [1:0] sclk_sync;
    reg [1:0] cs_sync;
    reg       sclk_prev;

    always @(posedge clk) begin
        sclk_sync <= {sclk_sync[0], SCLK};
        cs_sync   <= {cs_sync[0],   CS_N};
        sclk_prev <= sclk_sync[1];
    end

    wire sclk_s     = sclk_sync[1];
    wire cs_s       = cs_sync[1];
    wire sclk_fall  = ~sclk_s & sclk_prev;   // canh xuong SCLK (1 cycle clk)

    // ---- Thanh ghi ----------------------------------------------------------
    reg [7:0] tx_hold;                       // byte can gui, chot khi send_en
    reg [7:0] tx_sh;                         // thanh ghi dich dang gui
    reg [2:0] bit_cnt;                       // so canh xuong da dem (0..7)
    reg       sent;                          // da gui xong byte trong lan CS_N thap nay

    always @(posedge clk) begin
        if (rst) begin
            tx_hold <= 8'd0;
            tx_sh   <= 8'd0;
            bit_cnt <= 3'd0;
            sent    <= 1'b0;
            MISO    <= 1'b0;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;                 // mac dinh: pulse 1 cycle

            if (send_en)
                tx_hold <= data_in;          // chot byte can gui

            if (cs_s) begin
                // CS_N cao (ranh): nap san byte, dat MSB len MISO truoc canh len dau tien
                tx_sh   <= send_en ? data_in : tx_hold;
                MISO    <= send_en ? data_in[7] : tx_hold[7];
                bit_cnt <= 3'd0;
                sent    <= 1'b0;
            end else if (sclk_fall && !sent) begin
                if (bit_cnt == 3'd7) begin
                    // canh xuong thu 8: bit cuoi da duoc ESP32 lay mau o canh len truoc do
                    sent    <= 1'b1;
                    tx_done <= 1'b1;
                    MISO    <= 1'b0;
                end else begin
                    tx_sh   <= {tx_sh[6:0], 1'b0};
                    MISO    <= tx_sh[6];     // bit ke tiep (sau khi dich 1 bit)
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
