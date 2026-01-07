`timescale 1ns/1ps
module top_nopipe(
    input  [1:0] curr_qn_id,
    input signed [13:0] x0,y0,z0,
    input signed [13:0] x1,y1,z1,
    input signed [13:0] x2,y2,z2,
    input signed [13:0] x3,y3,z3,
    input  [7:0] bty0,bty1,bty2,bty3,
    input  [7:0] snr00,snr01,snr02,snr03,
                 snr10,snr11,snr12,snr13,
                 snr20,snr21,snr22,snr23,
                 snr30,snr31,snr32,snr33,
    output reg [1:0]  surr_qn_id,
    output reg [23:0] surr_score
);

integer i,j;

reg signed [15:0] dx[0:3][0:3], dy[0:3][0:3], dz[0:3][0:3];
reg [31:0] d2[0:3][0:3];
reg [31:0] ratio[0:3][0:3];
reg [31:0] worst[0:3];
reg [23:0] score[0:3];

reg signed [13:0] x[0:3], y[0:3], z[0:3];
reg [7:0] bty[0:3];
reg [7:0] snr[0:3][0:3];

always @(*) begin
    x[0]=x0; x[1]=x1; x[2]=x2; x[3]=x3;
    y[0]=y0; y[1]=y1; y[2]=y2; y[3]=y3;
    z[0]=z0; z[1]=z1; z[2]=z2; z[3]=z3;
    bty[0]=bty0; bty[1]=bty1; bty[2]=bty2; bty[3]=bty3;

    snr[0][0]=snr00; snr[0][1]=snr01; snr[0][2]=snr02; snr[0][3]=snr03;
    snr[1][0]=snr10; snr[1][1]=snr11; snr[1][2]=snr12; snr[1][3]=snr13;
    snr[2][0]=snr20; snr[2][1]=snr21; snr[2][2]=snr22; snr[2][3]=snr23;
    snr[3][0]=snr30; snr[3][1]=snr31; snr[3][2]=snr32; snr[3][3]=snr33;

    // distances
    for(i=0;i<4;i=i+1)
        for(j=0;j<4;j=j+1) begin
            dx[i][j] = x[i]-x[j];
            dy[i][j] = y[i]-y[j];
            dz[i][j] = z[i]-z[j];
            d2[i][j] = dx[i][j]*dx[i][j] + dy[i][j]*dy[i][j] + dz[i][j]*dz[i][j];
            ratio[i][j] = d2[i][j] / (snr[i][j]==0 ? 1 : snr[i][j]);
        end

    // worst links
    for(i=0;i<4;i=i+1) begin
        if(i==curr_qn_id)
            worst[i] = 32'hFFFFFFFF;
        else begin
            worst[i] = 0;
            for(j=0;j<4;j=j+1)
                if(j!=i && ratio[i][j] > worst[i])
                    worst[i] = ratio[i][j];
        end
    end

    // scores
    for(i=0;i<4;i=i+1)
        if(i==curr_qn_id)
            score[i]=0;
        else
            score[i] = (bty[i]<<16)/(worst[i]==0?1:worst[i]);

    // find best
    surr_score = 0;
    surr_qn_id = 0;
    for(i=0;i<4;i=i+1)
        if(score[i] > surr_score) begin
            surr_score = score[i];
            surr_qn_id = i[1:0];
        end
end

endmodule
