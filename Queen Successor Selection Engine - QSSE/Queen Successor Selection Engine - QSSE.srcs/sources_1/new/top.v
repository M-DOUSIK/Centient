`timescale 1ns / 1ps
module top (
    input clk,
    input rst,

    input [1:0] curr_qn_id,
    input a1, a2, a3, a4,

    input signed [13:0] x0, y0, z0,
    input signed [13:0] x1, y1, z1,
    input signed [13:0] x2, y2, z2,
    input signed [13:0] x3, y3, z3,

    input [7:0] bty0, bty1, bty2, bty3,

    input [7:0] snr00, snr01, snr02, snr03,
                snr10, snr11, snr12, snr13,
                snr20, snr21, snr22, snr23,
                snr30, snr31, snr32, snr33,

    output reg [1:0] surr_qn_id,
    output reg [23:0] surr_score,
    output reg valid
);

integer i,j;

/* =========================
   STAGE 1 - Input registers
   ========================= */
reg [1:0] qn1;
reg alive1[0:3];
reg signed [13:0] rx1[0:3], ry1[0:3], rz1[0:3];
reg [7:0] rbty1[0:3];
reg [7:0] snr1[0:3][0:3];

always @(posedge clk) begin
    if(rst) begin
        qn1 <= 0;
        alive1[0]<=0; alive1[1]<=0; alive1[2]<=0; alive1[3]<=0;
    end else begin
        qn1 <= curr_qn_id;
        alive1[0]<=a1; alive1[1]<=a2; alive1[2]<=a3; alive1[3]<=a4;

        rx1[0]<=x0; ry1[0]<=y0; rz1[0]<=z0;
        rx1[1]<=x1; ry1[1]<=y1; rz1[1]<=z1;
        rx1[2]<=x2; ry1[2]<=y2; rz1[2]<=z2;
        rx1[3]<=x3; ry1[3]<=y3; rz1[3]<=z3;

        rbty1[0]<=bty0; rbty1[1]<=bty1; rbty1[2]<=bty2; rbty1[3]<=bty3;

        snr1[0][0]<=snr00; snr1[0][1]<=snr01; snr1[0][2]<=snr02; snr1[0][3]<=snr03;
        snr1[1][0]<=snr10; snr1[1][1]<=snr11; snr1[1][2]<=snr12; snr1[1][3]<=snr13;
        snr1[2][0]<=snr20; snr1[2][1]<=snr21; snr1[2][2]<=snr22; snr1[2][3]<=snr23;
        snr1[3][0]<=snr30; snr1[3][1]<=snr31; snr1[3][2]<=snr32; snr1[3][3]<=snr33;
    end
end

/* Reliability */
always @(posedge clk)
    valid <= alive1[0] & alive1[1] & alive1[2] & alive1[3];

/* =========================
   STAGE 2 - dx,dy,dz
   ========================= */
reg signed [14:0] dx2[0:3][0:3], dy2[0:3][0:3], dz2[0:3][0:3];

always @(posedge clk)
for(i=0;i<4;i=i+1)
for(j=0;j<4;j=j+1) begin
    dx2[i][j] <= rx1[i] - rx1[j];
    dy2[i][j] <= ry1[i] - ry1[j];
    dz2[i][j] <= rz1[i] - rz1[j];
end

/* =========================
   STAGE 3 - squares
   ========================= */
reg [29:0] dxs[0:3][0:3], dys[0:3][0:3], dzs[0:3][0:3];

always @(posedge clk)
for(i=0;i<4;i=i+1)
for(j=0;j<4;j=j+1) begin
    dxs[i][j] <= dx2[i][j]*dx2[i][j];
    dys[i][j] <= dy2[i][j]*dy2[i][j];
    dzs[i][j] <= dz2[i][j]*dz2[i][j];
end

/* =========================
   STAGE 4 - d²
   ========================= */
reg [31:0] d2s[0:3][0:3];
always @(posedge clk)
for(i=0;i<4;i=i+1)
for(j=0;j<4;j=j+1)
    d2s[i][j] <= dxs[i][j] + dys[i][j] + dzs[i][j];

/* =========================
   STAGE 5 - d²/SNR
   ========================= */
reg [31:0] ratio[0:3][0:3];
always @(posedge clk)
for(i=0;i<4;i=i+1)
for(j=0;j<4;j=j+1)
    ratio[i][j] <= d2s[i][j] / (snr1[i][j]==0 ? 1 : snr1[i][j]);

/* =========================
   STAGE 6 - worst (max)
   ========================= */
reg [31:0] worst6[0:3];
always @(posedge clk)
for(i=0;i<4;i=i+1) begin
    worst6[i] <= 0;
    if(i!=qn1)
        for(j=0;j<4;j=j+1)
            if(j!=i && ratio[i][j] > worst6[i])
                worst6[i] <= ratio[i][j];
    else
        worst6[i] <= 32'hFFFFFFFF;
end

/* =========================
   STAGE 7 - score
   ========================= */
reg [23:0] score7[0:3];
always @(posedge clk)
for(i=0;i<4;i=i+1)
    score7[i] <= (i==qn1) ? 0 : (rbty1[i] << 16) / (worst6[i]==0?1:worst6[i]);

/* =========================
   STAGE 8 - best
   ========================= */
reg [23:0] best8;
reg [1:0] bestid8;

always @(posedge clk) begin
    best8 <= 0;
    bestid8 <= 0;
    for(i=0;i<4;i=i+1)
        if(score7[i] > best8) begin
            best8 <= score7[i];
            bestid8 <= i[1:0];
        end
end

/* =========================
   STAGE 9 - output
   ========================= */
always @(posedge clk) begin
    surr_qn_id <= bestid8;
    surr_score <= best8;
end

endmodule