`timescale 1ns/1ps

module mac_tb;

    logic        clk;
    logic        rst;
    logic signed [7:0]  a;
    logic signed [7:0]  b;
    logic signed [31:0] out;

    mac dut (.clk(clk), .rst(rst), .a(a), .b(b), .out(out));

    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;
    integer cycle;

    task apply_and_check(
        input signed [7:0]  in_a,
        input signed [7:0]  in_b,
        input signed [31:0] expected,
        input integer        cyc
    );
        @(posedge clk); #1;
        $display("cycle %0d | a=%4d b=%4d | product=%6d | expected=%10d | actual=%10d | %s",
            cyc,
            $signed(in_a),
            $signed(in_b),
            $signed(in_a) * $signed(in_b),
            expected,
            $signed(out),
            (out === expected) ? "PASS" : "FAIL"
        );
        if (out !== expected) errors = errors + 1;
    endtask

    initial begin
        errors = 0;
        cycle  = 0;
        rst = 1; a = 0; b = 0;

        // hold reset 2 cycles
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        $display("\n--- a=3, b=4 (3 cycles) ---");
        a = 3; b = 4;
        apply_and_check(a, b,  12, 1);
        apply_and_check(a, b,  24, 2);
        apply_and_check(a, b,  36, 3);

        $display("\n--- assert rst ---");
        rst = 1;
        @(posedge clk); #1;
        $display("cycle 4 | rst=1             | expected=%10d | actual=%10d | %s",
            32'sd0, $signed(out), (out === 0) ? "PASS" : "FAIL");
        if (out !== 0) errors = errors + 1;
        rst = 0;

        $display("\n--- a=-5, b=2 (2 cycles) ---");
        a = -5; b = 2;
        apply_and_check(a, b, -10, 5);
        apply_and_check(a, b, -20, 6);

        $display("\n--- Result: %s ---\n",
            (errors == 0) ? "ALL TESTS PASSED" : "TESTS FAILED");
        $finish;
    end

endmodule
