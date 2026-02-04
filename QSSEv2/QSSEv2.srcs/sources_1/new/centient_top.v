module centient_top #(
    parameter N = 256,
    parameter A_W = 8
)(
    input clk,
    input enable,
    
    input [7:0] num_drones,
    input [7:0] curr_qn_id,
    
    input we_ext,
    input [A_W-1:0] addr_ext,
    input [63:0] data_ext,
    
    output [7:0] best_id,
    output [31:0] best_score,
    output done
);

    wire [A_W-1:0] proc_mem_addr;
    wire [63:0]    proc_mem_data;

    ram #(
        .N(N), 
        .A_W(A_W)
    ) memory (
        .clk(clk),
        
        .we(we_ext),
        .w_addr(addr_ext),
        .w_data(data_ext),
        
        .r_addr(proc_mem_addr),
        .r_data(proc_mem_data)
    );

    processor #(
        .N(N), 
        .A_W(A_W)
    ) proc_unit (
        .clk(clk),
        .enable(enable),
        .num_drones(num_drones),
        .curr_qn_id(curr_qn_id),
        
        .mem_addr(proc_mem_addr),
        .mem_data(proc_mem_data),
        
        .best_id(best_id),
        .best_score(best_score),
        .done(done)
    );

endmodule