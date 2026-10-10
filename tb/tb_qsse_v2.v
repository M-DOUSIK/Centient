`timescale 1ns / 1ps

module tb_centient;
    parameter N = 256;
    parameter A_W = 8;

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

    centient_top #(.N(N), .A_W(A_W)) dut (
        .clk(clk), .enable(enable),            
        .num_drones(num_drones), .curr_qn_id(curr_qn_id),
        .we_ext(we_ext), .addr_ext(addr_ext), .data_ext(data_ext),
        .best_id(best_id), .best_score(best_score), .done(done)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
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

    initial begin
        clk = 0; enable = 0; we_ext = 0;
        curr_qn_id = 0;
        
        num_drones = 3; clear_ram();
        load_drone(0, 10, 0, 0, 0);   
        load_drone(1, 100, 5, 0, 0);  
        load_drone(2, 100, 20, 0, 0); 
        run_election_and_check(1, "1. Distance (Closer Wins)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 10, 10, 0, 0);  
        load_drone(2, 200, 10, 0, 0); 
        run_election_and_check(2, "2. Battery (Stronger Wins)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 250, 10, 0, 0); 
        load_drone(2, 5, 2, 0, 0);    
        run_election_and_check(1, "3. Hail Mary (Reliability Wins)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 10, 0, 0);     
        load_drone(2, 100, -5, 0, 0);     
        run_election_and_check(2, "4. Negative Coords (-5 is closer than 10)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 20, 0, 0); 
        load_drone(2, 100, 0, 0, 5); 
        run_election_and_check(2, "5. 3D Math (Z-axis Handling)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 20, 0, 0);
        load_drone(2, 0, 1, 0, 0);    
        run_election_and_check(1, "6. Dead Battery (0 Bat never wins)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 10, 0, 0); 
        load_drone(2, 100, 11, 0, 0); 
        run_election_and_check(1, "7. Precision (10 beats 11)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 10, 0, 0);
        load_drone(2, 100, 10, 0, 0);
        run_election_and_check(1, "8. Tie Breaker (First Valid ID Keeps Lead)");

        num_drones = 5;
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 20, 0, 0);
        load_drone(2, 100, 20, 0, 0);
        load_drone(3, 100, 20, 0, 0);
        load_drone(4, 255, 5, 0, 0);  
        run_election_and_check(4, "9. Crowd Test (5 Drones)");

        num_drones = 3; 
        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, -50, 0, 0);
        load_drone(2, 100, 40, 0, 0); 
        run_election_and_check(2, "10. Far Negative (-50 vs +40)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 3, 4, 0); 
        load_drone(2, 100, 5, 0, 0); 
        run_election_and_check(1, "11. Geometric Tie (Triangle vs Line)");

        clear_ram();
        load_drone(0, 10, 0, 0, 0);
        load_drone(1, 100, 1000, 1000, 1000); 
        load_drone(2, 100, 10, 10, 10);
        run_election_and_check(2, "12. Max Range Stress");

        clear_ram();
        load_drone(0, 255, 0, 0, 0); 
        load_drone(1, 50, 10, 0, 0);  
        load_drone(2, 10, 20, 0, 0);  
        run_election_and_check(1, "13. Queen Skip (Even if Queen is Best)");

        $display("ALL 13 TESTS COMPLETED.");
        $stop;
    end

endmodule