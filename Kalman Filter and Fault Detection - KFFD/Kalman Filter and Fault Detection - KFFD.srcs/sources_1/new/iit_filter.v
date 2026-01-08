`timescale 1ns / 1ps

module iir_filter(
input clk,
input rst,
input en,
input signed [15:0] ax, ay, az, gx, gy, gz,
output reg signed [15:0] ax_fil, ay_fil, az_fil,gx_fil, gy_fil, gz_fil
);

reg signed [31:0] state_ax, state_ay, state_az;
reg signed [31:0] state_gx, state_gy, state_gz;

always @(posedge clk or negedge rst) begin
    if (!rst) begin

        state_ax <= 32'd0; state_ay <= 32'd0; state_az <= 32'd0;
        state_gx <= 32'd0; state_gy <= 32'd0; state_gz <= 32'd0;

        ax_fil <= 16'd0; ay_fil <= 16'd0; az_fil <= 16'd0;
        gx_fil <= 16'd0; gy_fil <= 16'd0; gz_fil <= 16'd0;
    end
    else if (en) begin

        state_ax <= (230 * state_ax + 26 * (ax <<< 8)) >>> 8;
        ax_fil   <= state_ax >>> 8;

        state_ay <= (230 * state_ay + 26 * (ay <<< 8)) >>> 8;
        ay_fil   <= state_ay >>> 8;

        state_az <= (230 * state_az + 26 * (az <<< 8)) >>> 8;
        az_fil   <= state_az >>> 8;

        state_gx <= (230 * state_gx + 26 * (gx <<< 8)) >>> 8;
        gx_fil   <= state_gx >>> 8;

        state_gy <= (230 * state_gy + 26 * (gy <<< 8)) >>> 8;
        gy_fil   <= state_gy >>> 8;

        state_gz <= (230 * state_gz + 26 * (gz <<< 8)) >>> 8;
        gz_fil   <= state_gz >>> 8;
    end
end

endmodule