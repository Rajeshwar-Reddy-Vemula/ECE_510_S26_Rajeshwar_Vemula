// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module tb_compute_core;

    // -----------------------------------------------------------------------
    // Signals
    // -----------------------------------------------------------------------
    logic                clk;
    logic                rst;
    logic                start;

    logic signed [15:0]  ray_ox, ray_oy, ray_oz;
    logic signed [15:0]  ray_dx, ray_dy, ray_dz;
    logic signed [15:0]  sph_cx, sph_cy, sph_cz;
    logic signed [15:0]  sph_r;

    logic signed [15:0]  hit_distance;
    logic                hit_valid;
    logic                done;

    // -----------------------------------------------------------------------
    // Device Under Test (DUT)
    // -----------------------------------------------------------------------
    compute_core dut (.*);

    // -----------------------------------------------------------------------
    // Clock Generation
    // -----------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk; // 10ns period -> 100 MHz (Core runs independently of AXI freq here)

    // -----------------------------------------------------------------------
    // Verification Tracking
    // -----------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // -----------------------------------------------------------------------
    // Test Task
    // -----------------------------------------------------------------------
    task run_core_test(
        input string test_name,
        // Sphere Config (Q8.8)
        input signed [15:0] cx, input signed [15:0] cy, input signed [15:0] cz, input signed [15:0] r,
        // Ray Origin (Q8.8)
        input signed [15:0] ox, input signed [15:0] oy, input signed [15:0] oz,
        // Ray Direction (Q8.8)
        input signed [15:0] dx, input signed [15:0] dy, input signed [15:0] dz,
        // Expectations
        input expected_hit,
        input signed [15:0] expected_dist
    );
        integer latency;
        logic signed [15:0] abs_error;

        $display("\n--- Running Core Test: %s ---", test_name);
        $display("[INPUT] Ray O=(0x%04X, 0x%04X, 0x%04X), D=(0x%04X, 0x%04X, 0x%04X)", ox, oy, oz, dx, dy, dz);
        $display("[INPUT] Sph C=(0x%04X, 0x%04X, 0x%04X), R=0x%04X", cx, cy, cz, r);

        // Apply inputs
        @(negedge clk);
        sph_cx = cx; sph_cy = cy; sph_cz = cz; sph_r  = r;
        ray_ox = ox; ray_oy = oy; ray_oz = oz;
        ray_dx = dx; ray_dy = dy; ray_dz = dz;
        
        // Pulse Start
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        // Measure latency and wait for done
        latency = 0;
        while (!done) begin
            @(posedge clk);
            latency++;
            if (latency > 50) begin
                $display("[FAIL] %s: Timeout waiting for 'done' signal.", test_name);
                fail_count++;
                return;
            end
        end

        // Evaluate Results
        $display("[INFO] Pipeline latency: %0d clock cycles", latency);

        if (hit_valid !== expected_hit) begin
            $display("[FAIL] %s: hit_valid mismatch. Got %b, Expected %b", test_name, hit_valid, expected_hit);
            fail_count++;
        end else if (expected_hit == 1'b1) begin
            // Calculate Absolute Error for Q8.8 validation
            abs_error = hit_distance > expected_dist ? (hit_distance - expected_dist) : (expected_dist - hit_distance);
            
            // INCREASED TOLERANCE: Allow a quantization error threshold of 4 LSBs (approx 0.015)
            if (abs_error <= 16'sd4) begin
                $display("[PASS] %s: hit_distance=0x%04X (Expected=0x%04X, Error=%0d LSBs)", 
                          test_name, hit_distance, expected_dist, abs_error);
                pass_count++;
            end else begin
                $display("[FAIL] %s: hit_distance=0x%04X (Expected=0x%04X, Error=%0d LSBs)", 
                          test_name, hit_distance, expected_dist, abs_error);
                fail_count++;
            end
        end else begin
            // It's a correct miss
            $display("[PASS] %s: Correctly identified as a MISS.", test_name);
            pass_count++;
        end
    endtask

    // -------------------------------------
    initial begin
        // For waveform generation
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_compute_core);

        // Initialize
        start = 0;
        ray_ox = 0; ray_oy = 0; ray_oz = 0;
        ray_dx = 0; ray_dy = 0; ray_dz = 0;
        sph_cx = 0; sph_cy = 0; sph_cz = 0; sph_r = 0;

        $display("=======================================================");
        $display("STARTING COMPUTE CORE PIPELINE VERIFICATION");
        $display("=======================================================");

        // Reset
        rst = 1; repeat(5) @(posedge clk);
        rst = 0; repeat(2) @(posedge clk);

        // --- PREVIOUS TESTS ---
        run_core_test("T1_Direct_Z_Hit",
            16'h0000, 16'h0000, 16'h0500, 16'h0200, 
            16'h0000, 16'h0000, 16'h0000,           
            16'h0000, 16'h0000, 16'h0100,           
            1'b1, 16'h0300);

        run_core_test("T2_Miss_Behind",
            16'h0000, 16'h0000, 16'hFB00, 16'h0200, 
            16'h0000, 16'h0000, 16'h0000,           
            16'h0000, 16'h0000, 16'h0100,           
            1'b0, 16'h0000);

        run_core_test("T3_Grazing_Hit",
            16'h0200, 16'h0000, 16'h0500, 16'h0200, 
            16'h0000, 16'h0000, 16'h0000,           
            16'h0000, 16'h0000, 16'h0100,           
            1'b1, 16'h0500);

        run_core_test("T4_Diagonal_Hit",
            16'h01BB, 16'h01BB, 16'h01BB, 16'h0100, 
            16'h0000, 16'h0000, 16'h0000,           
            16'h0094, 16'h0094, 16'h0094,           
            1'b1, 16'h0200);

        run_core_test("T5_Inside_Sphere",
            16'h0000, 16'h0000, 16'h0000, 16'h0500, 
            16'h0000, 16'h0000, 16'h0000,           
            16'h0100, 16'h0000, 16'h0000,           
            1'b1, 16'h0500);

        // --- NEW ARBITRARY TESTS ---
        
        // -------------------------------------------------------------------
        // TEST 6: Arbitrary Fully 3D Hit 
        // Ray: O=(1, 2, -4), D=(2/7, 3/7, 6/7) -> (0.285, 0.428, 0.857)
        // Sph: C=(5, 8, 8), R=3.0
        // Expected: Hit, Dist = 11.0 (0x0B00)
        // -------------------------------------------------------------------
        run_core_test("T6_Arbitrary_3D_Hit",
            16'h0500, 16'h0800, 16'h0800, 16'h0300, 
            16'h0100, 16'h0200, 16'hFC00,           
            16'h0049, 16'h006E, 16'h00DB,           
            1'b1, 16'h0B00);

        // -------------------------------------------------------------------
        // TEST 7: Arbitrary Non-Zero Miss
        // Ray: O=(1, 2, -4), D=(2/7, 3/7, 6/7)
        // Sph: C=(10, -5, 2), R=2.0
        // Expected: Miss
        // -------------------------------------------------------------------
        run_core_test("T7_Arbitrary_Miss",
            16'h0A00, 16'hFB00, 16'h0200, 16'h0200, 
            16'h0100, 16'h0200, 16'hFC00,           
            16'h0049, 16'h006E, 16'h00DB,           
            1'b0, 16'h0000);

        // -------------------------------------------------------------------
        // TEST 8: Arbitrary Inside-Sphere Hit
        // Ray: O=(1, -2, 3), D=(0.577, 0.577, -0.577) 
        // Sph: C=(2, -1, 2), R=4.0
        // Expected: Hit on inside wall. Dist = 5.732 (0x05BB)
        // -------------------------------------------------------------------
        run_core_test("T8_Inside_Arbitrary_Hit",
            16'h0200, 16'hFF00, 16'h0200, 16'h0400, 
            16'h0100, 16'hFE00, 16'h0300,           
            16'h0094, 16'h0094, 16'hFF6C,           
            1'b1, 16'h05BB);

        // -------------------------------------------------------------------
        // TEST 9: All Negative Space Hit
        // Ray: O=(-10, -10, -10), D=(-0.577, -0.577, -0.577)
        // Sph: C=(-15, -15, -15), R=2.0
        // Expected: Hit, Dist = 6.660 (0x06A9)
        // -------------------------------------------------------------------
        run_core_test("T9_All_Negative_Hit",
            16'hF100, 16'hF100, 16'hF100, 16'h0200, 
            16'hF600, 16'hF600, 16'hF600,           
            16'hFF6C, 16'hFF6C, 16'hFF6C,           
            1'b1, 16'h06A9);

        $display("\n=======================================================");
        if (fail_count == 0) begin
            $display("COMPUTE CORE PIPELINE: ALL TESTS PASSED (%0d PASS)", pass_count);
        end else begin
            $display("COMPUTE CORE PIPELINE: SIMULATION FAILED (%0d FAIL)", fail_count);
        end
        $display("=======================================================\n");

        $finish;
    end

endmodule
