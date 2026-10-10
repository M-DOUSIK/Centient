// qstu_trigger.v
//
// This module contains the sequential (registered) logic for the QSTU.
// It latches the health score when appropriate and generates the final,
// stable trigger output.

`include "qstu_config.vh"

module qstu_trigger (
    input                                   clk,
    input                                   rst_n,

    // Inputs from Compute Module
    input signed [`SCORE_WIDTH-1:0]         health_score_next,
    input                                   fast_failure,
    input                                   slow_eval_en,

    // Inputs from Top-Level
    input                                   flight_stable,
    input signed [`THRESHOLD_WIDTH-1:0]     RED_BAND_THRESHOLD,

    // Final Output
    output reg                              elec_trigger
);

    reg signed [`SCORE_WIDTH-1:0] health_score_reg;

    // Registered Slow Path (stores health score only when needed)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            health_score_reg <= 16'd0;
        else if (slow_eval_en)
            health_score_reg <= health_score_next;
    end

    // Registered Trigger (generates the final output)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            elec_trigger <= 1'b0;
        else if (!flight_stable)
            elec_trigger <= 1'b0;
        else
            elec_trigger <= fast_failure |
                            (health_score_reg <= RED_BAND_THRESHOLD);
    end

endmodule