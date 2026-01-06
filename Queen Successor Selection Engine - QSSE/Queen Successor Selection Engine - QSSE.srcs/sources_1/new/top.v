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
    output [1:0] surr_qn_id,
    output [23:0] surr_score,
    output reg valid
);

    /* Registered inputs */
    reg [1:0] r_qn;
    reg alive[0:3];
    reg signed [13:0] rx[0:3], ry[0:3], rz[0:3];
    reg [7:0] bty[0:3];
    reg [7:0] snr[0:3][0:3];

    /* Distance and scoring */
    reg [29:0] d2[0:3][0:3];
    reg [31:0] worst[0:3];
    reg [23:0] score[0:3];

    integer i, j;

    /* Input sampling */
    always @(posedge clk) begin
        if (rst) begin
            r_qn <= 0;
            alive[0]<=0; alive[1]<=0; alive[2]<=0; alive[3]<=0;
        end else begin
            r_qn <= curr_qn_id;
            alive[0]<=a1; alive[1]<=a2; alive[2]<=a3; alive[3]<=a4;

            rx[0]<=x0; ry[0]<=y0; rz[0]<=z0;
            rx[1]<=x1; ry[1]<=y1; rz[1]<=z1;
            rx[2]<=x2; ry[2]<=y2; rz[2]<=z2;
            rx[3]<=x3; ry[3]<=y3; rz[3]<=z3;

            bty[0]<=bty0; bty[1]<=bty1; bty[2]<=bty2; bty[3]<=bty3;

            snr[0][0]<=snr00; snr[0][1]<=snr01; snr[0][2]<=snr02; snr[0][3]<=snr03;
            snr[1][0]<=snr10; snr[1][1]<=snr11; snr[1][2]<=snr12; snr[1][3]<=snr13;
            snr[2][0]<=snr20; snr[2][1]<=snr21; snr[2][2]<=snr22; snr[2][3]<=snr23;
            snr[3][0]<=snr30; snr[3][1]<=snr31; snr[3][2]<=snr32; snr[3][3]<=snr33;
        end
    end

    /* Reliability flag: all drones must be alive */
    always @(*) begin
        valid = alive[0] & alive[1] & alive[2] & alive[3];
    end

    /* Compute squared distances */
    always @(*) begin
        for (i=0;i<4;i=i+1)
            for (j=0;j<4;j=j+1)
                d2[i][j] = (rx[i]-rx[j])*(rx[i]-rx[j]) +
                           (ry[i]-ry[j])*(ry[i]-ry[j]) +
                           (rz[i]-rz[j])*(rz[i]-rz[j]);
    end

    /* Compute RF-weighted minimax (no alive filtering) */
    always @(*) begin
        for (i=0;i<4;i=i+1) begin
            worst[i] = 0;
            if (i == r_qn) begin
                worst[i] = 32'hFFFFFFFF;
                score[i] = 0;
            end else begin
                for (j=0;j<4;j=j+1)
                    if (j!=i)
                        if ((d2[i][j] / (snr[i][j]==0?1:snr[i][j])) > worst[i])
                            worst[i] = d2[i][j] / (snr[i][j]==0?1:snr[i][j]);
                score[i] = (bty[i] << 16) / (worst[i]==0?1:worst[i]);
            end
        end
    end

    /* Select best successor */
    reg [23:0] best_score;
    reg [1:0] best_id;
    always @(*) begin
        best_score = 0;
        best_id = 0;
        for (i=0;i<4;i=i+1)
            if (score[i] > best_score) begin
                best_score = score[i];
                best_id = i[1:0];
            end
    end

    assign surr_qn_id = best_id;
    assign surr_score = best_score;

endmodule