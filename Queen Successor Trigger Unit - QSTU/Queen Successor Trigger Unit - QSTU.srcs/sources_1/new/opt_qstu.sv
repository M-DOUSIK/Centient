module opt_qstu (
    input  logic               clk,
    input  logic               rst_n,

    input  logic               flight_stable,

    // Slow inputs
    input  logic [7:0]         bat_soc,          // Q0.8
    input  logic [7:0]         bat_soh,          // Q0.8
    input  logic signed [11:0] avg_temperature, // Q7.5
    input  logic [7:0]         link_quality,     // Q0.8

    // Fast inputs
    input  logic               bat_uv_flag,
    input  logic               thermal_trip,
    input  logic               comm_timeout,

    output logic               elec_trigger
);

    //========================================================
    // PARAMETERS
    //========================================================
    localparam signed [12:0] TEMP_MIN_Q = 13'sd640;   // 20°C
    localparam signed [12:0] TEMP_MAX_Q = 13'sd2560;  // 80°C

    // Temp health affine: (-1/60)*T + (80/60)
    localparam signed [15:0] TEMP_C1 = -16'sd546;    // Q1.15
    localparam signed [15:0] TEMP_C2 =  16'sd43690;  // Q1.15

    // Weights (Q1.15)
    localparam signed [15:0] W_SOC  = 16'sd8192;     // 0.25
    localparam signed [15:0] W_SOH  = 16'sd8192;     // 0.25
    localparam signed [15:0] W_TEMP = 16'sd8192;     // 0.25
    localparam signed [15:0] W_LINK = 16'sd8192;     // 0.25

    localparam signed [15:0] RED_BAND_THRESHOLD = 16'sd9830; // 0.3

    //========================================================
    // FAST FAILURE
    //========================================================
    logic fast_failure;
    assign fast_failure = bat_uv_flag | thermal_trip | comm_timeout;

    logic slow_eval_en;
    assign slow_eval_en = flight_stable & ~fast_failure;

    //========================================================
    // INTERNAL SIGNALS
    //========================================================
    logic signed [11:0] clmp_temp;

    logic signed [31:0] temp_mult;
    logic signed [15:0] temp_health_next;

    logic signed [31:0] soc_mult, soh_mult, temp_h_mult, link_mult;
    logic signed [31:0] score_accum;
    logic signed [15:0] health_score_next;

    logic signed [15:0] health_score_reg;

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
    // TEMPERATURE HEALTH (COMBINATIONAL)
    //========================================================
    always_comb begin
        temp_mult = clmp_temp * TEMP_C1;                 // Q7.5 × Q1.15
        temp_health_next = (temp_mult >>> 5) + TEMP_C2;  // Align to Q1.15

        if (temp_health_next < 0)
            temp_health_next = 16'sd0;
        else if (temp_health_next > 16'h7FFF)
            temp_health_next = 16'h7FFF;
    end

    //========================================================
    // HEALTH SCORE (COMBINATIONAL)
    //========================================================
    always_comb begin
        soc_mult    = bat_soc       * W_SOC;
        soh_mult    = bat_soh       * W_SOH;
        temp_h_mult = temp_health_next * W_TEMP;
        link_mult   = link_quality * W_LINK;

        score_accum =
              (soc_mult    >>> 8)
            + (soh_mult    >>> 8)
            + (temp_h_mult >>> 15)
            + (link_mult   >>> 8);

        if (score_accum < 0)
            health_score_next = 16'sd0;
        else if (score_accum > 16'h7FFF)
            health_score_next = 16'h7FFF;
        else
            health_score_next = score_accum[15:0];
    end

    //========================================================
    // REGISTERED SLOW PATH (CLOCK ENABLE)
    //========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            health_score_reg <= 16'd0;
        else if (slow_eval_en)
            health_score_reg <= health_score_next;
    end

    //========================================================
    // REGISTERED TRIGGER
    //========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            elec_trigger <= 1'b0;
        else if (!flight_stable)
            elec_trigger <= 1'b0;
        else
            elec_trigger <= fast_failure |
                            (health_score_reg <= RED_BAND_THRESHOLD);
    end

endmodule