module ram #(
    parameter N = 256, 
    parameter A_W = 8
)(
    input clk, 
    input we,
    input [A_W-1:0] w_addr,
    input [63:0] w_data,
    input [A_W-1:0] r_addr,
    output reg [63:0] r_data
);

    reg [63:0] mem [0:N-1];

    always @(posedge clk) begin
        if (we) begin
            mem[w_addr] <= w_data;
        end
        
        r_data <= mem[r_addr];
    end

endmodule