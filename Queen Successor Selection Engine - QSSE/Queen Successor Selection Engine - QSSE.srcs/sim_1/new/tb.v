`timescale 1ns/1ps
module tb;
reg [1:0] q;
reg signed [13:0] x0,y0,z0,x1,y1,z1,x2,y2,z2,x3,y3,z3;
reg [7:0] b0,b1,b2,b3;
wire [1:0] out;
wire [23:0] score;

top_nopipe dut(
    q,
    x0,y0,z0,x1,y1,z1,x2,y2,z2,x3,y3,z3,
    b0,b1,b2,b3,
    100,100,100,100,
    100,100,100,100,
    100,100,100,100,
    100,100,100,100,
    out,score
);

initial begin
    $display("QN  SCORE");

    // V1
    q=0; x0=0;x1=10;x2=20;x3=50; y0=0;y1=0;y2=0;y3=0; z0=0;z1=0;z2=0;z3=0;
    b0=100;b1=100;b2=100;b3=100;
    #1 $display("%d  %d",out,score);

    // V2
    q=0; b1=50; b2=200; b3=100;
    #1 $display("%d  %d",out,score);

    // V3
    q=1; b0=200;b1=100;b2=50;b3=50;
    #1 $display("%d  %d",out,score);

    // V4
    q=2; x0=0;x1=5;x2=10;x3=15;
    b0=100;b1=100;b2=100;b3=100;
    #1 $display("%d  %d",out,score);

    $finish;
end
endmodule
