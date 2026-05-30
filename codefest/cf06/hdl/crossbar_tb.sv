`timescale 1ns/1ps

module crossbar_tb;
    localparam int N         = 4;
    localparam int IN_WIDTH  = 8;
    localparam int OUT_WIDTH = IN_WIDTH + $clog2(N) + 1; // 11

    logic clk = 0;
    logic rst_n = 0;
    logic load_w = 0;

    logic                          weight_in [N][N];
    logic signed [IN_WIDTH-1:0]    in_vec    [N];
    logic signed [OUT_WIDTH-1:0]   out_vec   [N];

    // 10 ns clock
    always #5 clk = ~clk;

    // DUT instance
    crossbar_mac #(.N(N), .IN_WIDTH(IN_WIDTH)) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .load_w   (load_w),
        .weight_in(weight_in),
        .in_vec   (in_vec),
        .out_vec  (out_vec)
    );

    // Expected results, computed by hand
    int expected [N] = '{-40, 0, -20, -20};

    initial begin
        // Weight matrix W[i][j], 1 = +1, 0 = -1
        //              col0 col1 col2 col3
        // row 0:  +1   -1   +1   -1
        // row 1:  +1   +1   -1   -1
        // row 2:  -1   +1   +1   -1
        // row 3:  -1   -1   -1   +1
        weight_in[0] = '{1, 0, 1, 0};
        weight_in[1] = '{1, 1, 0, 0};
        weight_in[2] = '{0, 1, 1, 0};
        weight_in[3] = '{0, 0, 0, 1};

        // Input vector
        in_vec[0] = 8'sd10;
        in_vec[1] = 8'sd20;
        in_vec[2] = 8'sd30;
        in_vec[3] = 8'sd40;

        // Reset
        rst_n = 0;
        #12;
        rst_n = 1;

        // Pulse load_w for one clock to latch weights
        @(posedge clk);
        load_w <= 1'b1;
        @(posedge clk);
        load_w <= 1'b0;

        // Wait for combinational MAC + output register to settle
        @(posedge clk);
        @(posedge clk);

        // Print results
        $display("--- Crossbar MAC results ---");
        for (int j = 0; j < N; j++) begin
            $display("out[%0d] = %0d  (expected %0d)  %s",
                     j, out_vec[j], expected[j],
                     (out_vec[j] === expected[j]) ? "PASS" : "FAIL");
        end

        // Strict check
        for (int j = 0; j < N; j++) begin
            assert (out_vec[j] === expected[j])
              else $fatal(1, "Mismatch at out[%0d]: got %0d expected %0d",
                          j, out_vec[j], expected[j]);
        end

        $display("ALL CHECKS PASSED");
        $finish;
    end

    // Safety timeout
    initial begin
        #1000;
        $display("TIMEOUT");
        $fatal(1, "Simulation timed out");
    end

endmodule
