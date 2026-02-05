`timescale 1ns/1ps

`include "qstu_config.vh"

module qstu_subsystem_tb;

    reg                                   clk;
    reg                                   rst_n;

    reg                                   flight_stable;
    reg       [`HEALTH_PARAM_WIDTH-1:0]   bat_soc;
    reg       [`HEALTH_PARAM_WIDTH-1:0]   bat_soh;
    reg signed [`TEMP_WIDTH-1:0]          avg_temperature;
    reg       [`HEALTH_PARAM_WIDTH-1:0]   link_quality;
    reg                                   bat_uv_flag;
    reg                                   thermal_trip;
    reg                                   comm_timeout;

    reg signed [`TEMP_LIMIT_WIDTH-1:0]    cfg_temp_min_q;
    reg signed [`TEMP_LIMIT_WIDTH-1:0]    cfg_temp_max_q;
    reg signed [`WEIGHT_WIDTH-1:0]        cfg_temp_c1;
    reg signed [`WEIGHT_WIDTH-1:0]        cfg_temp_c2;
    reg signed [`WEIGHT_WIDTH-1:0]        cfg_w_soc;
    reg signed [`WEIGHT_WIDTH-1:0]        cfg_w_soh;
    reg signed [`WEIGHT_WIDTH-1:0]        cfg_w_temp;
    reg signed [`WEIGHT_WIDTH-1:0]        cfg_w_link;
    reg signed [`THRESHOLD_WIDTH-1:0]     cfg_red_band_threshold;

    wire                                  elec_trigger;

    localparam signed [12:0] P_TEMP_MIN_Q = 13'sd640;
    localparam signed [12:0] P_TEMP_MAX_Q = 13'sd2560;
    localparam signed [15:0] P_TEMP_C1 = -16'sd546;
    localparam signed [15:0] P_TEMP_C2 =  16'sd43690;
    localparam signed [15:0] P_W_SOC  = 16'sd8192;
    localparam signed [15:0] P_W_SOH  = 16'sd8192;
    localparam signed [15:0] P_W_TEMP = 16'sd8192;
    localparam signed [15:0] P_W_LINK = 16'sd8192;
    localparam signed [15:0] P_RED_BAND_THRESHOLD = 16'sd9830;

    qstu_subsystem dut (
        .clk(clk),
        .rst_n(rst_n),
        .flight_stable(flight_stable),
        .bat_soc(bat_soc),
        .bat_soh(bat_soh),
        .avg_temperature(avg_temperature),
        .link_quality(link_quality),
        .bat_uv_flag(bat_uv_flag),
        .thermal_trip(thermal_trip),
        .comm_timeout(comm_timeout),
        .cfg_temp_min_q(cfg_temp_min_q),
        .cfg_temp_max_q(cfg_temp_max_q),
        .cfg_temp_c1(cfg_temp_c1),
        .cfg_temp_c2(cfg_temp_c2),
        .cfg_w_soc(cfg_w_soc),
        .cfg_w_soh(cfg_w_soh),
        .cfg_w_temp(cfg_w_temp),
        .cfg_w_link(cfg_w_link),
        .cfg_red_band_threshold(cfg_red_band_threshold),
        .elec_trigger(elec_trigger)
    );

    always #5 clk = ~clk;

    task reset_and_config_dut;
    begin
        clk = 0;
        rst_n = 0;
        flight_stable = 0;
        bat_soc = 0;
        bat_soh = 0;
        avg_temperature = 0;
        link_quality = 0;
        bat_uv_flag = 0;
        thermal_trip = 0;
        comm_timeout = 0;

        cfg_temp_min_q = P_TEMP_MIN_Q;
        cfg_temp_max_q = P_TEMP_MAX_Q;
        cfg_temp_c1 = P_TEMP_C1;
        cfg_temp_c2 = P_TEMP_C2;
        cfg_w_soc = P_W_SOC;
        cfg_w_soh = P_W_SOH;
        cfg_w_temp = P_W_TEMP;
        cfg_w_link = P_W_LINK;
        cfg_red_band_threshold = P_RED_BAND_THRESHOLD;

        #20;
        rst_n = 1;
        #10;
    end
    endtask

    initial begin
        $display("\n======================================================");
        $display("     STARTING QSTU SUBSYSTEM TESTBENCH");
        $display("======================================================");

        $dumpfile("simulation.vcd");
        $dumpvars(0, qstu_subsystem_tb);

        reset_and_config_dut();

        bat_soc = 8'd255;
        bat_soh = 8'd255;
        link_quality = 8'd255;
        avg_temperature = 12'sd1280;
        flight_stable = 0;
        #20;
        $display("[%0t ns] TEST  1: Flight stable    (EXPECT 0) -> TRIGGER = %0d", $time, elec_trigger);

        flight_stable = 1;
        bat_soc = 8'd230;
        bat_soh = 8'd240;
        link_quality = 8'd220;
        avg_temperature = 12'sd1280;
        #20;
        $display("[%0t ns] TEST  2: Healthy system       (EXPECT 0) -> TRIGGER = %0d", $time, elec_trigger);

        bat_uv_flag = 1;
        #10;
        $display("[%0t ns] TEST  3: Fast Fail - UV Flag   (EXPECT 1) -> TRIGGER = %0d", $time, elec_trigger);
        bat_uv_flag = 0;
        #10;

        thermal_trip = 1;
        #10;
        $display("[%0t ns] TEST  4: Fast Fail - Thermal  (EXPECT 1) -> TRIGGER = %0d", $time, elec_trigger);
        thermal_trip = 0;
        #10;

        comm_timeout = 1;
        #10;
        $display("[%0t ns] TEST  5: Fast Fail - Comm     (EXPECT 1) -> TRIGGER = %0d", $time, elec_trigger);
        comm_timeout = 0;
        #10;

        bat_uv_flag = 1;
        thermal_trip = 1;
        #10;
        $display("[%0t ns] TEST  6: Multiple Fast Fails  (EXPECT 1) -> TRIGGER = %0d", $time, elec_trigger);
        bat_uv_flag = 0;
        thermal_trip = 0;
        #10;

        avg_temperature = 12'sd0;
        bat_soc = 8'd200;
        bat_soh = 8'd200;
        link_quality = 8'd200;
        #20;
        $display("[%0t ns] TEST  7: Temp below MIN clamp (EXPECT 0) -> TRIGGER = %0d", $time, elec_trigger);

        avg_temperature = 12'sd4000;
        #20;
        $display("[%0t ns] TEST  8: Temp above MAX clamp (EXPECT 0) -> TRIGGER = %0d", $time, elec_trigger);

        bat_soc = 8'd40;
        bat_soh = 8'd50;
        link_quality = 8'd40;
        avg_temperature = 12'sd2560;
        #20;
        $display("[%0t ns] TEST  9: Score below RED      (EXPECT 1) -> TRIGGER = %0d", $time, elec_trigger);

        bat_soc = 8'd240;
        bat_soh = 8'd240;
        link_quality = 8'd240;
        avg_temperature = 12'sd1280;
        #20;
        $display("[%0t ns] TEST 10: Health recovered     (EXPECT 0) -> TRIGGER = %0d", $time, elec_trigger);

        $display("\n======================================================");
        $display("              TESTBENCH COMPLETE");
        $display("======================================================");
        $finish;
    end

endmodule