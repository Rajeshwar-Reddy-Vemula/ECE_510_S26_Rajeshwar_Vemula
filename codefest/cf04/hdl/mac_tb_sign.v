`timescale 1ns/1ps
module mac_tb_sign;
    logic        clk;
    logic        rst;
    logic signed [7:0]  a;
    logic signed [7:0]  b;
    logic signed [31:0] out;

    mac dut (.clk(clk), .rst(rst), .a(a), .b(b), .out(out));
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1; a = 0; b = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 0;

        // Test: a=-1 b=1 → product should be -1
        // mac_llm_B uses 32'(a) which zero-extends -1 to 255
        // so product becomes 255 instead of -1
        a = -1; b = 1;
        @(posedge clk); #1;
        $display("a=-1 b=1 | expected=-1 | actual=%0d | %s",
            $signed(out),
            ($signed(out) === -32'sd1) ? "PASS" : "FAIL ← sign extension bug");

        // Test: a=-128 b=1 → product should be -128
        rst = 1; @(posedge clk); #1; rst = 0;
        a = -128; b = 1;
        @(posedge clk); #1;
        $display("a=-128 b=1 | expected=-128 | actual=%0d | %s",
            $signed(out),
            ($signed(out) === -32'sd128) ? "PASS" : "FAIL ← sign extension bug");

        $finish;
    end
endmodule
