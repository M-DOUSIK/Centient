//============================================================
// Queen Succession Trigger Unit (QSTU)
//============================================================
// - Detects fast failures (event-driven)
// - Computes slow health score (periodic inputs)
// - Triggers QSSE when required
//============================================================

module QSTU (
    input  logic              clk,
    input  logic              rst_n,

    // -------------------------
    // Control
    // -------------------------
    input  logic              flight_stable,

    // -------------------------
    // Slow time-varying inputs
    // -------------------------
    input  logic [7:0]        bat_soc,          // Q0.8
    input  logic [7:0]        bat_soh,          // Q0.8
    input  logic signed [11:0] avg_temperature, // Q7.5
    input  logic [7:0]        link_quality,     // Q0.8

    // -------------------------
    // Fast time-varying inputs
    // -------------------------
    input  logic              bat_uv_flag,
    input  logic              thermal_trip,
    input  logic              comm_timeout,

    // -------------------------
    // Output
    // -------------------------
    output logic              elec_trigger
);

    //========================================================
    // PARAMETERS
    //========================================================

    // Temperature limits (Q7.5)
    localparam signed [12:0] TEMP_MIN_Q = 13'sd640;   // 20 * 2^5
    localparam signed [12:0] TEMP_MAX_Q = 13'sd2560;  // 80 * 2^5

    // Min-max scaling constants for temperature health
    // temp_health = (-1/60)*T + (80/60)
    // Q1.15 format
    localparam signed [15:0] TEMP_C1 = -16'sd546;    // -1/60
    localparam signed [15:0] TEMP_C2 =  16'sd43690;  // 80/60

    // Health score weights (Q1.15) - example values
    localparam signed [15:0] W_SOC  = 16'sd8192;  // 0.25
    localparam signed [15:0] W_SOH  = 16'sd8192;  // 0.25
    localparam signed [15:0] W_TEMP = 16'sd8192;  // 0.25
    localparam signed [15:0] W_LINK = 16'sd8192;  // 0.25

    // Red band threshold (0.3 in Q1.15)
    localparam signed [15:0] RED_BAND_THRESHOLD = 16'sd9830;

    //========================================================
    // INTERNAL SIGNALS
    //========================================================

    logic signed [11:0] clmp_temp;
    logic signed [31:0] temp_mult;
    logic signed [15:0] temp_health;

    logic signed [31:0] soc_mult, soh_mult, temp_h_mult, link_mult;
    logic signed [31:0] score_accum;
    logic signed [15:0] health_score;

    logic fast_failure;

    //========================================================
    // TEMPERATURE CLAMP
    //========================================================
    always_comb begin
        if (avg_temperature < TEMP_MIN_Q)
            clmp_temp = TEMP_MIN_Q;
        else if (avg_temperature > TEMP_MAX_Q)
            clmp_temp = TEMP_MAX_Q;
        else
            clmp_temp = avg_temperature;
    end

    //========================================================
    // TEMPERATURE HEALTH (Affine Mapping)
    //========================================================
    always_comb begin
        temp_mult   = clmp_temp * TEMP_C1;          // Q7.5 * Q1.15 → Q8.20
        temp_health = (temp_mult >>> 5) + TEMP_C2;  // Align to Q1.15

        // Saturation
        if (temp_health < 0)
            temp_health = 16'sd0;
        else if (temp_health > 16'sh7FFF)
            temp_health = 16'sh7FFF;
    end

    //========================================================
    // FAST FAILURE DETECTION
    //========================================================
    assign fast_failure = bat_uv_flag | thermal_trip | comm_timeout;

    //========================================================
    // HEALTH SCORE COMPUTATION
    //========================================================
    always_comb begin
        soc_mult    = bat_soc       * W_SOC;   // Q0.8 * Q1.15 → Q1.23
        soh_mult    = bat_soh       * W_SOH;
        temp_h_mult = temp_health  * W_TEMP;  // Q1.15 * Q1.15 → Q2.30
        link_mult   = link_quality * W_LINK;

        score_accum =
              (soc_mult    >>> 8)
            + (soh_mult    >>> 8)
            + (temp_h_mult >>> 15)
            + (link_mult   >>> 8);

        // Saturate to Q1.15
        if (score_accum < 0)
            health_score = 16'sd0;
        else if (score_accum > 16'sh7FFF)
            health_score = 16'sh7FFF;
        else
            health_score = score_accum[15:0];
    end

    //========================================================
    // TRIGGER LOGIC
    //========================================================
    always_comb begin
        if (!flight_stable)
            elec_trigger = 1'b0;
        else if (fast_failure)
            elec_trigger = 1'b1;
        else if (health_score <= RED_BAND_THRESHOLD)
            elec_trigger = 1'b1;
        else
            elec_trigger = 1'b0;
    end

endmodule