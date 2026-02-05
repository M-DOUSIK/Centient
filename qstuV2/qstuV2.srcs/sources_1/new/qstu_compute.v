// qstu_compute.v
//
// This module contains the purely combinational logic for the QSTU.
// It calculates the drone's health score based on sensor inputs and
// dynamic configuration parameters.

`include "qstu_config.vh"

module qstu_compute (
    // Sensor and Status Inputs
    input                                   flight_stable,
    input       [`HEALTH_PARAM_WIDTH-1:0]   bat_soc,
    input       [`HEALTH_PARAM_WIDTH-1:0]   bat_soh,
    input signed [`TEMP_WIDTH-1:0]          avg_temperature,
    input       [`HEALTH_PARAM_WIDTH-1:0]   link_quality,
    input                                   bat_uv_flag,
    input                                   thermal_trip,
    input                                   comm_timeout,

    // Configuration Inputs (from top-level)
    input signed [`TEMP_LIMIT_WIDTH-1:0]    TEMP_MIN_Q,
    input signed [`TEMP_LIMIT_WIDTH-1:0]    TEMP_MAX_Q,
    input signed [`WEIGHT_WIDTH-1:0]        TEMP_C1,
    input signed [`WEIGHT_WIDTH-1:0]        TEMP_C2,
    input signed [`WEIGHT_WIDTH-1:0]        W_SOC,
    input signed [`WEIGHT_WIDTH-1:0]        W_SOH,
    input signed [`WEIGHT_WIDTH-1:0]        W_TEMP,
    input signed [`WEIGHT_WIDTH-1:0]        W_LINK,

    // Outputs to the trigger logic module
    output reg signed [`SCORE_WIDTH-1:0]    health_score_next,
    output                                  fast_failure,
    output                                  slow_eval_en
);

    // --- Internal Combinational Signals ---
    reg signed [`TEMP_WIDTH-1:0]      clmp_temp;
    reg signed [`MULT_WIDTH-1:0]      temp_mult;
    reg signed [`SCORE_WIDTH-1:0]     temp_health_next;
    reg signed [`MULT_WIDTH-1:0]      soc_mult, soh_mult, temp_h_mult, link_mult;
    reg signed [`ACCUM_WIDTH-1:0]      score_accum;

    // --- Fast Failure and Slow Path Enable Logic ---
    assign fast_failure = bat_uv_flag | thermal_trip | comm_timeout;
    assign slow_eval_en = flight_stable & ~fast_failure;

    // --- Combinational Logic Blocks ---
    always @(*) begin
        // 1. Temperature Clamp
        if (avg_temperature < TEMP_MIN_Q)
            clmp_temp = TEMP_MIN_Q;
        else if (avg_temperature > TEMP_MAX_Q)
            clmp_temp = TEMP_MAX_Q;
        else
            clmp_temp = avg_temperature;

        // 2. Temperature Health Calculation (Affine)
        temp_mult = clmp_temp * TEMP_C1;
        temp_health_next = (temp_mult >> 5) + TEMP_C2; // Align to Q1.15

        if (temp_health_next < 0)
            temp_health_next = 16'd0;
        else if (temp_health_next > 16'h7FFF)
            temp_health_next = 16'h7FFF;

        // 3. Final Health Score Calculation
        soc_mult    = bat_soc       * W_SOC;
        soh_mult    = bat_soh       * W_SOH;
        temp_h_mult = temp_health_next * W_TEMP;
        link_mult   = link_quality * W_LINK;

        score_accum =
              (soc_mult    >> 8)
            + (soh_mult    >> 8)
            + (temp_h_mult >> 15)
            + (link_mult   >> 8);

        if (score_accum < 0)
            health_score_next = 16'd0;
        else if (score_accum > 16'h7FFF)
            health_score_next = 16'h7FFF;
        else
            health_score_next = score_accum[`SCORE_WIDTH-1:0];
    end

endmodule