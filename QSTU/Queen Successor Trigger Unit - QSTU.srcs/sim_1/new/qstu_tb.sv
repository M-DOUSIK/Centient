`timescale 1ns/1ps
//define USE_OPT_QSTU   // Comment this line to test QSTU instead

module qstu_tb;

    // -------------------------------------------------
    // DUT Signals
    // -------------------------------------------------
    logic              clk;
    logic              rst_n;
    logic              flight_stable;

    logic [7:0]        bat_soc;
    logic [7:0]        bat_soh;
    logic signed [11:0] avg_temperature;
    logic [7:0]        link_quality;

    logic              bat_uv_flag;
    logic              thermal_trip;
    logic              comm_timeout;

    logic              elec_trigger;

    // -------------------------------------------------
    // Instantiate DUT (Selectable)
    // -------------------------------------------------
`ifdef USE_OPT_QSTU
    opt_qstu dut (
`else
    QSTU dut (
`endif
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

        .elec_trigger(elec_trigger)
    );

    // -------------------------------------------------
    // Clock Generation
    // -------------------------------------------------
    always #5 clk = ~clk;

    // -------------------------------------------------
    // Utility Tasks
    // -------------------------------------------------
    task reset_dut;
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

        #20;
        rst_n = 1;
        #10;
    end
    endtask

    task show_status(string label);
    begin
        $display("[%0t] %s | TRIGGER=%0d",
                 $time, label, elec_trigger);
    end
    endtask

    // -------------------------------------------------
    // Test Sequence
    // -------------------------------------------------
    initial begin
        $display("========================================");
`ifdef USE_OPT_QSTU
        $display(" TESTING opt_qstu");
`else
        $display(" TESTING QSTU");
`endif
        $display("========================================");

        $dumpfile("simulation.vcd");
        $dumpvars(0, qstu_tb);

        reset_dut();

        // ---------------------------------------------
        // TEST 1: Flight not stable → trigger must be 0
        // ---------------------------------------------
        bat_soc = 8'd255;
        bat_soh = 8'd255;
        link_quality = 8'd255;
        avg_temperature = 12'sd1280; // 40C
        flight_stable = 0;

        #20;
        show_status("TEST1: flight_stable=0 (EXPECT 0)");

        // ---------------------------------------------
        // TEST 2: Healthy system → no trigger
        // ---------------------------------------------
        flight_stable = 1;
        bat_soc = 8'd230;
        bat_soh = 8'd240;
        link_quality = 8'd220;
        avg_temperature = 12'sd1280;

        #20;
        show_status("TEST2: healthy inputs (EXPECT 0)");

        // ---------------------------------------------
        // TEST 3: Fast failure - undervoltage
        // ---------------------------------------------
        bat_uv_flag = 1;
        #10;
        show_status("TEST3: bat_uv_flag=1 (EXPECT 1)");
        bat_uv_flag = 0;

        // ---------------------------------------------
        // TEST 4: Fast failure - thermal trip
        // ---------------------------------------------
        thermal_trip = 1;
        #10;
        show_status("TEST4: thermal_trip=1 (EXPECT 1)");
        thermal_trip = 0;

        // ---------------------------------------------
        // TEST 5: Fast failure - comm timeout
        // ---------------------------------------------
        comm_timeout = 1;
        #10;
        show_status("TEST5: comm_timeout=1 (EXPECT 1)");
        comm_timeout = 0;

        // ---------------------------------------------
        // TEST 6: Multiple fast failures
        // ---------------------------------------------
        bat_uv_flag = 1;
        thermal_trip = 1;
        #10;
        show_status("TEST6: multiple fast failures (EXPECT 1)");
        bat_uv_flag = 0;
        thermal_trip = 0;

        // ---------------------------------------------
        // TEST 7: Temperature below MIN → clamp
        // ---------------------------------------------
        avg_temperature = 12'sd0;
        bat_soc = 8'd200;
        bat_soh = 8'd200;
        link_quality = 8'd200;

        #20;
        show_status("TEST7: temp below MIN (EXPECT 0)");

        // ---------------------------------------------
        // TEST 8: Temperature above MAX → clamp
        // ---------------------------------------------
        avg_temperature = 12'sd4000;
        #20;
        show_status("TEST8: temp above MAX");

        // ---------------------------------------------
        // TEST 9: Force score below RED threshold
        // ---------------------------------------------
        bat_soc = 8'd40;
        bat_soh = 8'd50;
        link_quality = 8'd40;
        avg_temperature = 12'sd2560;

        #20;
        show_status("TEST9: score < RED (EXPECT 1)");

        // ---------------------------------------------
        // TEST 10: Recovery
        // ---------------------------------------------
        bat_soc = 8'd240;
        bat_soh = 8'd240;
        link_quality = 8'd240;
        avg_temperature = 12'sd1280;

        #20;
        show_status("TEST10: recovered health (EXPECT 0)");

        $display("========================================");
        $display(" TEST COMPLETE");
        $display("========================================");
        $finish;
    end

endmodule