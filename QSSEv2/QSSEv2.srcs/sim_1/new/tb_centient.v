`timescale 1ns / 1ps

module tb_centient;

    // ============================================================
    // 1. CONFIGURATION
    // ============================================================
    parameter N = 256;
    parameter A_W = 8;

    // Signals
    reg clk;
    reg enable;      
    reg [7:0] num_drones;
    reg [7:0] curr_qn_id;
    reg we_ext;
    reg [A_W-1:0] addr_ext;
    reg [63:0] data_ext;
    wire [7:0] best_id;
    wire [31:0] best_score;
    wire done;

    // ============================================================
    // 2. DUT INSTANTIATION
    // ============================================================
    centient_top #(.N(N), .A_W(A_W)) dut (
        .clk(clk), .enable(enable),            
        .num_drones(num_drones), .curr_qn_id(curr_qn_id),
        .we_ext(we_ext), .addr_ext(addr_ext), .data_ext(data_ext),
        .best_id(best_id), .best_score(best_score), .done(done)
    );

    // ============================================================
    // 3. CLOCK & TASKS
    // ============================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz Clock
    end

    task load_drone;
        input [7:0] id;
        input [7:0] bat;
        input signed [15:0] x, y, z;
        begin
            @(posedge clk);
            we_ext = 1; addr_ext = id;
            data_ext = {id, bat, z, y, x};
            @(posedge clk);
            we_ext = 0;
        end
    endtask

    task clear_ram;
        integer k;
        begin
            for (k=0; k<10; k=k+1) load_drone(k, 0, 0, 0, 0);
        end
    endtask

    task run_election_and_check;
        input [7:0] expected_id;
        input [8*60:1] test_name; 
        begin
            $display("--------------------------------------------------");
            $display("SCENARIO: %s", test_name);
            
            enable = 0; #20;
            enable = 1;
            wait(done);
            #20;
            
            if (best_id == expected_id)
                $display(" [PASS] Winner: %d | Score: %d", best_id, best_score);
            else
                $display(" [FAIL] Winner: %d (Expected %d) | Score: %d", best_id, expected_id, best_score);
            $display("--------------------------------------------------\n");
        end
    endtask

    // ============================================================
    // 4. THE 13 SCENARIOS
    // ============================================================
    initial begin
        // Defaults
        clk = 0; enable = 0; we_ext = 0;
        curr_qn_id = 0;
        
        // --- 1. BASELINE: DISTANCE DOMINANCE ---
        // Drone 1 is Closer (5) than Drone 2 (20). Winner: 1.
        num_drones = 3; clear_ram();
        load_drone(0, 10, 0, 0, 0);   
        load_drone(1, 100, 5, 0, 0);  // Close
        load_drone(2, 100, 20, 0, 0); // Far
        run_election_and_check(1, "1. Distance (Closer Wins)");

        // --- 2. BASELINE: BATTERY DOMINANCE ---
        // Equal Dist (10). Drone 2 has 20x battery. Winner: 2.
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 10, 10, 0, 0);  // Weak
        load_drone(2, 200, 10, 0, 0); // Strong
        run_election_and_check(2, "2. Battery (Stronger Wins)");

        // --- 3. BASELINE: HAIL MARY ---
        // Drone 1 Far/Strong vs Drone 2 Close/Dead. Winner: 1.
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 250, 10, 0, 0); // Far+Strong
        load_drone(2, 5, 2, 0, 0);    // Close+Dead
        run_election_and_check(1, "3. Hail Mary (Reliability Wins)");

        // --- 4. SIGNED MATH: NEGATIVE COORDINATES ---
        // Drone 1 at +10. Drone 2 at -5.
        // |-5| is closer to 0 than |+10|. Winner: 2.
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 10, 0, 0);     // DistSq=100
        load_drone(2, 100, -5, 0, 0);     // DistSq=25 (Should handle signed math)
        run_election_and_check(2, "4. Negative Coords (-5 is closer than 10)");

        // --- 5. 3D SPACE: Z-AXIS BIAS ---
        // Drone 1 is far on X (20,0,0). Drone 2 is close on Z (0,0,5).
        // System must calculate X^2+Y^2+Z^2. Winner: 2.
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 20, 0, 0); // X-axis far
        load_drone(2, 100, 0, 0, 5);  // Z-axis close
        run_election_and_check(2, "5. 3D Math (Z-axis Handling)");

        // --- 6. THE DEAD BATTERY TRAP ---
        // Drone 2 is PERFECTLY positioned (1,0,0) but has 0 Battery.
        // Drone 1 is far (20) but has battery.
        // Winner: 1 (Because Score = 0/Dist = 0).
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 20, 0, 0); // Valid
        load_drone(2, 0, 1, 0, 0);    // Dead (0 Bat)
        run_election_and_check(1, "6. Dead Battery (0 Bat never wins)");

        // --- 7. PRECISION TEST: THE PHOTO FINISH ---
        // Drone 1 at 10. Drone 2 at 11.
        // Difference is tiny, but 10 is better. Winner: 1.
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 10, 0, 0); // Sq=100
        load_drone(2, 100, 11, 0, 0); // Sq=121
        run_election_and_check(1, "7. Precision (10 beats 11)");

        // --- 8. THE CLONE WAR (TIE BREAKER) ---
        // Drone 1 and Drone 2 are IDENTICAL.
        // Logic: if (new > max). Since equal is not >, the FIRST valid one found (1) holds.
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 10, 0, 0);
        load_drone(2, 100, 10, 0, 0);
        run_election_and_check(1, "8. Tie Breaker (First Valid ID Keeps Lead)");

        // --- 9. THE CROWD (5 DRONES) ---
        // Increase Num Drones. 
        // 0(Q), 1(Weak), 2(Weak), 3(Weak), 4(SUPER STRONG).
        num_drones = 5;
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 20, 0, 0);
        load_drone(2, 100, 20, 0, 0);
        load_drone(3, 100, 20, 0, 0);
        load_drone(4, 255, 5, 0, 0);  // The clear winner
        run_election_and_check(4, "9. Crowd Test (5 Drones)");

        // --- 10. THE "FAR NEGATIVE" ---
        // Drone 1 at -50. Drone 2 at +40.
        // +40 (Sq 1600) is better than -50 (Sq 2500). Winner: 2.
        num_drones = 3; // Reset to 3
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, -50, 0, 0);
        load_drone(2, 100, 40, 0, 0); 
        run_election_and_check(2, "10. Far Negative (-50 vs +40)");

        // --- 11. THE DIAGONAL ---
        // Drone 1 at (3,4,0). DistSq = 9+16 = 25.
        // Drone 2 at (5,0,0). DistSq = 25.
        // It's a geometric tie. First ID (1) should win.
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 3, 4, 0); // 3-4-5 Triangle
        load_drone(2, 100, 5, 0, 0); // Straight line 5
        run_election_and_check(1, "11. Geometric Tie (Triangle vs Line)");

        // --- 12. MAX RANGE STRESS ---
        // Drone 1 at (1000, 1000, 1000). Sq = 3,000,000.
        // Drone 2 at (10, 10, 10).
        // Ensure accumulators don't overflow. Winner: 2.
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 1000, 1000, 1000); 
        load_drone(2, 100, 10, 10, 10);
        run_election_and_check(2, "12. Max Range Stress");

        // --- 13. SELF PRESERVATION (Queen has best stats) ---
        // If Queen has Bat 255 and Pos 0, she WOULD win.
        // But the hardware 'skip' logic (if i == curr_qn_id) MUST prevent this.
        // Winner should be the next best (Drone 1).
        clear_ram();
        load_drone(0, 255, 0, 0, 0);  // The Perfect Queen
        load_drone(1, 50, 10, 0, 0);  // Mediocre Drone
        load_drone(2, 10, 20, 0, 0);  // Bad Drone
        run_election_and_check(1, "13. Queen Skip (Even if Queen is Best)");

        $display("ALL 13 TESTS COMPLETED.");
        $stop;
    end

endmodule