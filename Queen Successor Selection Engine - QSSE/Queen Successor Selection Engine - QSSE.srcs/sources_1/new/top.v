`timescale 1ns / 1ps

module qsse_top (
    /* Global control */
    input              clk,          // System clock
    input              rst,          // Synchronous reset

    /* Swarm control */
    input  [1:0]       curr_qn_id,   // Current Queen ID (excluded from successor selection)
    input              a1, a2, a3, a4, // Alive flags for drones 0-3

    /* Drone positions (fixed-point) */
    input  signed [13:0] x0, y0, z0,   // Drone 0 position
    input  signed [13:0] x1, y1, z1,   // Drone 1 position
    input  signed [13:0] x2, y2, z2,   // Drone 2 position
    input  signed [13:0] x3, y3, z3,   // Drone 3 position

    /* Battery levels */
    input  [7:0]       bty0, bty1, bty2, bty3, // Battery for drones 0-3

    /* RF link SNR matrix */
    input  [7:0]       snr00, snr01, snr02, snr03,
                       snr10, snr11, snr12, snr13,
                       snr20, snr21, snr22, snr23,
                       snr30, snr31, snr32, snr33, // SNR from drone i to j

    /* QSSE outputs */
    output [1:0]           surr_qn_id,   // Selected successor Queen ID
    output [23:0]          surr_score,   // Successor score
    output reg             valid         // Output is valid
);
    /* Integers */
    integer h, i, j, k, l, m, n;
    
    /* Input register file */
    reg [1:0] r_curr_qn_id;
    reg r_a1, r_a2, r_a3, r_a4;
    reg signed [13:0] rx0, ry0, rz0;
    reg signed [13:0] rx1, ry1, rz1;
    reg signed [13:0] rx2, ry2, rz2;
    reg signed [13:0] rx3, ry3, rz3;
    reg [7:0] rbty0, rbty1, rbty2, rbty3;
    reg [7:0] rsnr00, rsnr01, rsnr02, rsnr03;
    reg [7:0] rsnr10, rsnr11, rsnr12, rsnr13;
    reg [7:0] rsnr20, rsnr21, rsnr22, rsnr23;
    reg [7:0] rsnr30, rsnr31, rsnr32, rsnr33;

    /* Synchronous input sampling */
    always @(posedge clk) begin
        if (rst) begin
            r_curr_qn_id <= 2'b00;
            r_a1 <= 1'b0; r_a2 <= 1'b0; r_a3 <= 1'b0; r_a4 <= 1'b0;
            rx0 <= 0; ry0 <= 0; rz0 <= 0;
            rx1 <= 0; ry1 <= 0; rz1 <= 0;
            rx2 <= 0; ry2 <= 0; rz2 <= 0;
            rx3 <= 0; ry3 <= 0; rz3 <= 0;
            rbty0 <= 0; rbty1 <= 0; rbty2 <= 0; rbty3 <= 0;
            rsnr00 <= 0; rsnr01 <= 0; rsnr02 <= 0; rsnr03 <= 0;
            rsnr10 <= 0; rsnr11 <= 0; rsnr12 <= 0; rsnr13 <= 0;
            rsnr20 <= 0; rsnr21 <= 0; rsnr22 <= 0; rsnr23 <= 0;
            rsnr30 <= 0; rsnr31 <= 0; rsnr32 <= 0; rsnr33 <= 0;
        end
        else begin
            r_curr_qn_id <= curr_qn_id;
            r_a1 <= a1; r_a2 <= a2; r_a3 <= a3; r_a4 <= a4;
            rx0 <= x0; ry0 <= y0; rz0 <= z0;
            rx1 <= x1; ry1 <= y1; rz1 <= z1;
            rx2 <= x2; ry2 <= y2; rz2 <= z2;
            rx3 <= x3; ry3 <= y3; rz3 <= z3;
            rbty0 <= bty0; rbty1 <= bty1; rbty2 <= bty2; rbty3 <= bty3;
            rsnr00 <= snr00; rsnr01 <= snr01; rsnr02 <= snr02; rsnr03 <= snr03;
            rsnr10 <= snr10; rsnr11 <= snr11; rsnr12 <= snr12; rsnr13 <= snr13;
            rsnr20 <= snr20; rsnr21 <= snr21; rsnr22 <= snr22; rsnr23 <= snr23;
            rsnr30 <= snr30; rsnr31 <= snr31; rsnr32 <= snr32; rsnr33 <= snr33;
        end
    end
    
    /* 4×4 SNR matrix for internal computation */
    reg [7:0] snr_mat [0:3][0:3];
    
    /* Map SNR registers into matrix form */
    always @(*) begin
        snr_mat[0][0] = rsnr00; snr_mat[0][1] = rsnr01; snr_mat[0][2] = rsnr02; snr_mat[0][3] = rsnr03;
        snr_mat[1][0] = rsnr10; snr_mat[1][1] = rsnr11; snr_mat[1][2] = rsnr12; snr_mat[1][3] = rsnr13;
        snr_mat[2][0] = rsnr20; snr_mat[2][1] = rsnr21; snr_mat[2][2] = rsnr22; snr_mat[2][3] = rsnr23;
        snr_mat[3][0] = rsnr30; snr_mat[3][1] = rsnr31; snr_mat[3][2] = rsnr32; snr_mat[3][3] = rsnr33;
    end
    
    
    /* 4x4 Distance square matrix for internal computation */
    reg [29:0] d2_mat [0:3][0:3];
    
    /* Placeholders */
    reg signed [14:0] dx, dy, dz;
    reg [29:0] dx2, dy2, dz2;
    
    /* Calculate the Distance square values and map them into matrix form */
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin

                case (i)
                    0: begin dx = rx0 - (j==0?rx0 : j==1?rx1 : j==2?rx2 : rx3);
                              dy = ry0 - (j==0?ry0 : j==1?ry1 : j==2?ry2 : ry3);
                              dz = rz0 - (j==0?rz0 : j==1?rz1 : j==2?rz2 : rz3); end
                    1: begin dx = rx1 - (j==0?rx0 : j==1?rx1 : j==2?rx2 : rx3);
                              dy = ry1 - (j==0?ry0 : j==1?ry1 : j==2?ry2 : ry3);
                              dz = rz1 - (j==0?rz0 : j==1?rz1 : j==2?rz2 : rz3); end
                    2: begin dx = rx2 - (j==0?rx0 : j==1?rx1 : j==2?rx2 : rx3);
                              dy = ry2 - (j==0?ry0 : j==1?ry1 : j==2?ry2 : ry3);
                              dz = rz2 - (j==0?rz0 : j==1?rz1 : j==2?rz2 : rz3); end
                    3: begin dx = rx3 - (j==0?rx0 : j==1?rx1 : j==2?rx2 : rx3);
                              dy = ry3 - (j==0?ry0 : j==1?ry1 : j==2?ry2 : ry3);
                              dz = rz3 - (j==0?rz0 : j==1?rz1 : j==2?rz2 : rz3); end
                endcase

                dx2 = dx * dx;
                dy2 = dy * dy;
                dz2 = dz * dz;

                d2_mat[i][j] = dx2 + dy2 + dz2;
            end
        end
    end
    
    /* 4*1 Battery Matrix */
    reg [7:0] bty [0:3];
    
    /* Map battery value into matrix form */
    always@(*) begin
        bty[0] = rbty0;
        bty[1] = rbty1;
        bty[2] = rbty2;
        bty[3] = rbty3;
    end
    
    /* Maximum Scores and Maximum Distance-SNR Ratios */
    reg [23:0] score [0:3];
    reg [31:0] denm [0:3];
    
    /* Placeholder */
    reg [23:0] tscore;
    reg [1:0] tid;
        
    /* Computing Engine */
    always@(*) begin
        for (h = 0; h < 4; h = h + 1) begin
            score[h] = 24'd0;
            denm[h]  = 32'd0;
        end
        if (&{r_a1, r_a2, r_a3, r_a4}) valid = 1'b1;
        else valid = 1'b0;
        for (k = 0; k < 4; k = k + 1) begin
            for (l = 0; l < 4; l = l + 1) begin
                if ((d2_mat[k][l] / snr_mat[k][l]) > denm[k]) denm[k] = (d2_mat[k][l] / snr_mat[k][l]); 
            end
        end
        for (m = 0; m < 4; m = m + 1) begin
            if (m != r_curr_qn_id) begin
                score[m] = bty[m] / denm[m];
            end
            else begin
                score[m] = 24'd0;
            end
        end
        tscore = {24{1'b0}};
        tid = 2'd0;
        for (n = 0; n < 4; n = n + 1) begin
            if (score[n] > tscore) begin
                tscore = score[n];
                tid = n;
            end
        end
    end
    assign surr_qn_id = tid;
    assign surr_score = tscore;
endmodule
