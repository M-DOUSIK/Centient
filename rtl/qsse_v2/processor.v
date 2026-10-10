module processor #(
    parameter N = 256, 
    parameter A_W = 8
)(
    input clk, 
    input enable, 
    input [7:0] num_drones, 
    input [7:0] curr_qn_id,

    output reg [A_W-1:0] mem_addr,  // Address to read
    input      [63:0]    mem_data,  // Data from RAM

    output reg [7:0] best_id,
    output reg [31:0] best_score, 
    output reg done
);

    reg start_math;
    wire valid_math;
    reg signed [15:0] cand_x, cand_y, cand_z;
    reg signed [15:0] neigh_x, neigh_y, neigh_z;
    reg [7:0] neigh_bty;
    wire signed [31:0] out_score;
    
    reg [7:0] r_cand_id;

    reg signed [31:0] current_total_score;
    reg signed [31:0] max_score;

    score_calc msc(
        .clk(clk), 
        .start(start_math), 
        .cand_x(cand_x), .cand_y(cand_y), .cand_z(cand_z), 
        .neigh_x(neigh_x), .neigh_y(neigh_y), .neigh_z(neigh_z), 
        .neigh_bty(neigh_bty), 
        .out_score(out_score), 
        .valid(valid_math)
    );

    wire signed [15:0] ram_x  = mem_data[15:0];
    wire signed [15:0] ram_y  = mem_data[31:16];
    wire signed [15:0] ram_z  = mem_data[47:32];
    wire [7:0]         ram_b  = mem_data[55:48];
    wire [7:0]         ram_id = mem_data[63:56];

    reg [7:0] i; 
    reg [7:0] j; 
    
    reg [3:0] state;
    localparam S_IDLE=0;
    localparam S_FETCH_I=1, S_WAIT_I=2, S_STORE_I=3; 
    localparam S_FETCH_J=4, S_WAIT_J=5, S_CALC=6, S_ACCUM=7; 
    localparam S_UPDATE=8, S_DONE=9;

    always @(posedge clk or negedge enable) begin
        if (!enable) begin
            best_id <= 8'dx;
            best_score <= 32'd0;
            done <= 1'b0;
            start_math <= 1'b0;
            max_score <= -1; 
            state <= S_IDLE;
            mem_addr <= 0;
        end else begin
            case(state)
                S_IDLE: begin
                    if (num_drones > 0) begin
                        i <= 0;
                        state <= S_FETCH_I;
                    end
                end

                S_FETCH_I: begin
                    if (i >= num_drones) state <= S_DONE;
                    else if (i == curr_qn_id) i <= i + 1; 
                    else begin
                        mem_addr <= i; 
                        state <= S_WAIT_I;
                    end
                end

                S_WAIT_I: state <= S_STORE_I; 

                S_STORE_I: begin
                    cand_x <= ram_x; cand_y <= ram_y; cand_z <= ram_z; 
                    neigh_bty <= ram_b; 
                    r_cand_id <= ram_id;
                    j <= 0;
                    current_total_score <= 0;
                    state <= S_FETCH_J;
                end

                S_FETCH_J: begin
                    if (j >= num_drones) state <= S_UPDATE;
                    else if (j == i) j <= j + 1; 
                    else begin
                        mem_addr <= j; 
                        state <= S_WAIT_J;
                    end
                end

                S_WAIT_J: state <= S_CALC;

                S_CALC: begin
                    neigh_x <= ram_x;   neigh_y <= ram_y;   neigh_z <= ram_z;

                    start_math <= 1;
                    state <= S_ACCUM;
                end

                S_ACCUM: begin
                    if (valid_math) begin
                        if (out_score > current_total_score)
                            current_total_score <= out_score;
                        j <= j + 1;
                        state <= S_FETCH_J;
                        start_math <= 0;
                    end else state <= S_ACCUM;
                end

                S_UPDATE: begin
                    if (current_total_score > max_score) begin
                        max_score <= current_total_score;
                        best_score <= current_total_score;
                        best_id <= r_cand_id;
                    end
                    i <= i + 1;
                    state <= S_FETCH_I;
                end

                S_DONE: done <= 1;
            endcase
        end
    end
endmodule