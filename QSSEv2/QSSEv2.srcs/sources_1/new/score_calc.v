module score_calc(
    input clk,
    input start,
    
    input signed [15:0] cand_x, cand_y, cand_z,
    input signed [15:0] neigh_x, neigh_y, neigh_z,
    input [7:0] neigh_bty,
    
    output reg signed [31:0] out_score,
    output reg valid
);

    reg signed [15:0] diff;
    reg signed [31:0] diff_sq;
    reg signed [31:0] dist_sq_sum;

    localparam S_RESET = 0, S_CALC_X = 1, S_CALC_Y = 2, S_CALC_Z = 3, S_DIV = 4;
    
    reg [2:0] state = S_RESET; 

    always @(posedge clk) begin
        case (state)
            S_RESET: begin
                valid <= 0;
                out_score <= 0;     
                dist_sq_sum <= 0;  
                
                if (start) state <= S_CALC_X;
            end

            S_CALC_X: begin
                diff = cand_x - neigh_x;
                diff_sq = (diff * diff);
                dist_sq_sum <= dist_sq_sum + diff_sq;
                state <= S_CALC_Y;
            end

            S_CALC_Y: begin
                diff = cand_y - neigh_y;
                diff_sq = (diff * diff);
                dist_sq_sum <= dist_sq_sum + diff_sq;
                state <= S_CALC_Z;
            end

            S_CALC_Z: begin
                diff = cand_z - neigh_z;
                diff_sq = (diff * diff);
                dist_sq_sum <= dist_sq_sum + diff_sq;
                state <= S_DIV;
            end

            S_DIV: begin
                if (dist_sq_sum == 0)
                    out_score <= 32'hFFFFFFFF;
                else
                    out_score <= ({8'b0, neigh_bty, 16'b0}) / dist_sq_sum;
                
                valid <= 1;
                state <= S_RESET;
            end
        endcase
    end

endmodule