`timescale 1ns / 1ps

module tb;
reg clk=0, rst=0, en=0;
reg signed [15:0] ax=0, ay=0, az=0, gx=0, gy=0, gz=0;
wire signed [15:0] ax_fil, ay_fil, az_fil, gx_fil, gy_fil, gz_fil;

iir_filter dut(
    .clk(clk), .rst(rst), .en(en),
    .ax(ax), .ay(ay), .az(az),
    .gx(gx), .gy(gy), .gz(gz),
    .ax_fil(ax_fil), .ay_fil(ay_fil), .az_fil(az_fil),
    .gx_fil(gx_fil), .gy_fil(gy_fil), .gz_fil(gz_fil)
);

always #5 clk = ~clk;

initial begin

    #20 rst = 1;
    #10 en  = 1;

    $display("\\n--- Test 1: Accelerometer Step ---");
    #20 ax = 1000; ay = 2000; az = 3000;
    #2000;

    $display("\\n--- Test 2: Gyroscope Step ---");
    gx = -500; gy = 1500; gz = -1000;
    #2000;

    $display("\\n--- Test 3: All Axes Change ---");
    ax = -800; ay = 500; az = 1200;
    gx = 300; gy = -700; gz = 900;
    #3000;

    $display("\\n--- Test 4: Decay to Zero ---");
    ax = 0; ay = 0; az = 0;
    gx = 0; gy = 0; gz = 0;
    #3000;

    $display("\\n✓ All Tests Complete!");
    $finish;
end

endmodule