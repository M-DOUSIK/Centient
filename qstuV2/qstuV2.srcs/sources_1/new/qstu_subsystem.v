// qstu_subsystem.v
//
// Top-level wrapper for the hierarchical Queen Successor Trigger Unit.
// This module instantiates the compute and trigger sub-modules.
// Configuration parameters are provided as inputs to this wrapper.

`include "qstu_config.vh"

module qstu_subsystem (
    input                                   clk,
    input                                   rst_n,

    // Sensor and Status Inputs
    input                                   flight_stable,
    input       [`HEALTH_PARAM_WIDTH-1:0]   bat_soc,
    input       [`HEALTH_PARAM_WIDTH-1:0]   bat_soh,
    input signed [`TEMP_WIDTH-1:0]          avg_temperature,
    input       [`HEALTH_PARAM_WIDTH-1:0]   link_quality,
    input                                   bat_uv_flag,
    input                                   thermal_trip,
    input                                   comm_timeout,

    // Runtime Configuration Inputs
    input signed [`TEMP_LIMIT_WIDTH-1:0]    cfg_temp_min_q,
    input signed [`TEMP_LIMIT_WIDTH-1:0]    cfg_temp_max_q,
    input signed [`WEIGHT_WIDTH-1:0]        cfg_temp_c1,
    input signed [`WEIGHT_WIDTH-1:0]        cfg_temp_c2,
    input signed [`WEIGHT_WIDTH-1:0]        cfg_w_soc,
    input signed [`WEIGHT_WIDTH-1:0]        cfg_w_soh,
    input signed [`WEIGHT_WIDTH-1:0]        cfg_w_temp,
    input signed [`WEIGHT_WIDTH-1:0]        cfg_w_link,
    input signed [`THRESHOLD_WIDTH-1:0]     cfg_red_band_threshold,

    // Final Trigger Output
    output                                  elec_trigger
);

    // --- Internal wires to connect sub-modules ---
    wire signed [`SCORE_WIDTH-1:0]    w_health_score_next;
    wire                              w_fast_failure;
    wire                              w_slow_eval_en;

    // Instantiate the Combinational Compute Block
    qstu_compute compute_unit (
        .flight_stable      (flight_stable),
        .bat_soc            (bat_soc),
        .bat_soh            (bat_soh),
        .avg_temperature    (avg_temperature),
        .link_quality       (link_quality),
        .bat_uv_flag        (bat_uv_flag),
        .thermal_trip       (thermal_trip),
        .comm_timeout       (comm_timeout),

        .TEMP_MIN_Q         (cfg_temp_min_q),
        .TEMP_MAX_Q         (cfg_temp_max_q),
        .TEMP_C1            (cfg_temp_c1),
        .TEMP_C2            (cfg_temp_c2),
        .W_SOC              (cfg_w_soc),
        .W_SOH              (cfg_w_soh),
        .W_TEMP             (cfg_w_temp),
        .W_LINK             (cfg_w_link),

        .health_score_next  (w_health_score_next),
        .fast_failure       (w_fast_failure),
        .slow_eval_en       (w_slow_eval_en)
    );

    // Instantiate the Sequential Trigger Block
    qstu_trigger trigger_unit (
        .clk                (clk),
        .rst_n              (rst_n),

        .health_score_next  (w_health_score_next),
        .fast_failure       (w_fast_failure),
        .slow_eval_en       (w_slow_eval_en),

        .flight_stable      (flight_stable),
        .RED_BAND_THRESHOLD (cfg_red_band_threshold),

        .elec_trigger       (elec_trigger)
    );

endmodule