// =============================================================================
// Module:      tb_top
// File:        tb_top.sv
// Project:     Ray-Object Intersection Accelerator — ECE 510 HW4AI Spring 2026
//
// Description:
//   End-to-end M3 co-simulation testbench.
//   Drives top module through AXI4-Lite (sphere + ray origin config)
//   and AXI4-Stream (ray direction input / hit result output).
//   No direct access to compute_core or interface_top internal signals.
//
//   8 test vectors across 3 spheres from scene_city.json.
//   Expected values from Python FP64 intersect_sphere() reference.
//
// Compile (VCS):
//   vcs -full64 -sverilog -timescale=1ns/1ns \
//       project/m3/rtl/compute_core.sv \
//       project/m3/rtl/interface_top.sv \
//       project/m3/rtl/top.sv \
//       project/m3/tb/tb_top.sv -o sim_m3
// Run: ./sim_m3
// =============================================================================

`timescale 1ns/1ps

module tb_top;

    logic        clk, rst;

    // AXI4-Lite
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awvalid, s_axi_awready;
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid,  s_axi_wready;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid,  s_axi_bready;
    logic [31:0] s_axi_araddr;
    logic        s_axi_arvalid, s_axi_arready;
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid,  s_axi_rready;

    // AXI4-Stream
    logic [63:0] s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tready;
    logic [63:0] m_axis_tdata;
    logic        m_axis_tvalid;
    logic        m_axis_tready;

    // -----------------------------------------------------------------------
    // DUT
    // -----------------------------------------------------------------------
    top dut (
        .clk(clk), .rst(rst),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count, fail_count, test_num;

    // -----------------------------------------------------------------------
    // AXI4-Lite write task
    // -----------------------------------------------------------------------
    task axi_write(input [31:0] addr, input [31:0] data);
        @(negedge clk);
        s_axi_awaddr  = addr;
        s_axi_awvalid = 1;
        s_axi_wdata   = data;
        s_axi_wvalid  = 1;
        s_axi_wstrb   = 4'hF;
        s_axi_bready  = 1;
        @(posedge clk);
        while (!(s_axi_awready && s_axi_wready)) @(posedge clk);
        @(negedge clk);
        s_axi_awvalid = 0;
        s_axi_wvalid  = 0;
        @(posedge clk);
        while (!s_axi_bvalid) @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 0;
    endtask

    // -----------------------------------------------------------------------
    // AXI4-Lite read task
    // -----------------------------------------------------------------------
    task axi_read(input [31:0] addr, output [31:0] rdata);
        @(negedge clk);
        s_axi_araddr  = addr;
        s_axi_arvalid = 1;
        s_axi_rready  = 1;
        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        @(negedge clk);
        s_axi_arvalid = 0;
        @(posedge clk);
        while (!s_axi_rvalid) @(posedge clk);
        rdata = s_axi_rdata;
        @(negedge clk);
        s_axi_rready = 0;
    endtask

    // -----------------------------------------------------------------------
    // Load sphere via AXI4-Lite
    // -----------------------------------------------------------------------
    task load_sphere(
        input [15:0] cx, input [15:0] cy,
        input [15:0] cz, input [15:0] r
    );
        axi_write(32'h1C, {16'b0, cx});
        axi_write(32'h20, {16'b0, cy});
        axi_write(32'h24, {16'b0, cz});
        axi_write(32'h28, {16'b0, r});
    endtask

    // -----------------------------------------------------------------------
    // Load ray origin via AXI4-Lite
    // -----------------------------------------------------------------------
    task load_ray_origin(
        input [15:0] ox, input [15:0] oy, input [15:0] oz
    );
        axi_write(32'h04, {16'b0, ox});
        axi_write(32'h08, {16'b0, oy});
        axi_write(32'h0C, {16'b0, oz});
    endtask

    // -----------------------------------------------------------------------
    // Send ray direction via AXI4-Stream, wait for result on output stream
    // -----------------------------------------------------------------------
    task run_intersection(
        input  [15:0] dx, input [15:0] dy, input [15:0] dz,
        output [15:0] result_t,
        output logic  result_valid
    );
        integer timeout;

        // pack ray direction into AXI4-Stream: {unused[63:48], dz, dy, dx}
        @(negedge clk);
        s_axis_tdata  = {16'h0000, dz, dy, dx};
        s_axis_tvalid = 1'b1;

        // wait for tready handshake
        @(posedge clk);
        while (!s_axis_tready) @(posedge clk);
        @(negedge clk);
        s_axis_tvalid = 1'b0;

        // wait for result on m_axis
        timeout = 0;
        while (!m_axis_tvalid && timeout < 100) begin
            @(posedge clk);
            timeout++;
        end

        if (m_axis_tvalid) begin
            result_t     = m_axis_tdata[15:0];
            result_valid = 1'b1;
        end else begin
            result_t     = 16'h0000;
            result_valid = 1'b0;
            $display("TIMEOUT: m_axis_tvalid not asserted within 100 cycles");
        end

        // consume the output
        @(negedge clk);
        @(posedge clk);
    endtask

    // -----------------------------------------------------------------------
    // Check result
    // -----------------------------------------------------------------------
    task check_result(
        input string  desc,
        input logic   expect_hit,
        input [15:0]  expect_t,
        input logic   actual_valid,
        input [15:0]  actual_t
    );
        logic t_match, hit_match;

        hit_match = (actual_valid == expect_hit);
        if (expect_hit)
            t_match = ($signed(actual_t) >= $signed(expect_t) - 2) &&
                      ($signed(actual_t) <= $signed(expect_t) + 2);
        else
            t_match = 1;

        if (hit_match && t_match) begin
            if (expect_hit)
                $display("PASS  TEST%0d — %s: hit=1 t=0x%04X (%.4f)",
                    test_num, desc, actual_t,
                    $itor($signed(actual_t))/256.0);
            else
                $display("PASS  TEST%0d — %s: miss (no intersection)",
                    test_num, desc);
            pass_count++;
        end else begin
            $display("FAIL  TEST%0d — %s: valid=%0b(exp %0b) t=0x%04X(exp 0x%04X)",
                test_num, desc, actual_valid, expect_hit, actual_t, expect_t);
            fail_count++;
        end
        test_num++;
    endtask

    // -----------------------------------------------------------------------
    // Main test
    // -----------------------------------------------------------------------
    logic [15:0] result_t;
    logic        result_valid;

    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num   = 1;

        s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s_axi_arvalid = 0; s_axi_rready = 0;
        s_axi_awaddr  = 0; s_axi_wdata  = 0; s_axi_wstrb  = 0;
        s_axi_araddr  = 0;
        s_axis_tdata  = 0; s_axis_tvalid = 0;
        m_axis_tready = 1;

        rst = 1;
        repeat(4) @(posedge clk); #1;
        rst = 0;
        repeat(4) @(posedge clk); #1;

        $display("");
        $display("================================================================");
        $display("  M3 Co-Simulation — Ray-Sphere Intersection Accelerator");
        $display("  Protocol: AXI4-Lite (config) + AXI4-Stream (ray data)");
        $display("  Scene: scene_city.json — 3 spheres");
        $display("  Kernel: intersect_sphere (dominant from M1 profiling)");
        $display("  Format: Q8.8 fixed-point, tolerance ±2 LSB");
        $display("================================================================");

        // =================================================================
        // Load ray origin (same for all tests): (0, 0.35, -1)
        // =================================================================
        load_ray_origin(16'h0000, 16'h005A, 16'hFF00);

        // =================================================================
        // BLUE SPHERE: center(0, 0, 1.5) r=0.45
        // =================================================================
        $display("");
        $display("--- Blue sphere: center(0, 0, 1.5) r=0.45 ---");
        load_sphere(16'h0000, 16'h0000, 16'h0180, 16'h0073);

        // TEST 1: straight ahead → HIT t=2.2188 (0x0238)
        run_intersection(16'h0000, 16'h0000, 16'h0100, result_t, result_valid);
        check_result("straight ahead → blue", 1'b1, 16'h0238,
                     result_valid, result_t);

        // TEST 2: slight right → HIT t=2.3555 (0x025B)
        run_intersection(16'h001A, 16'h0000, 16'h00FF, result_t, result_valid);
        check_result("slight right → blue", 1'b1, 16'h025B,
                     result_valid, result_t);

        // TEST 3: grazing incidence → HIT t=2.0742 (0x0213)
        run_intersection(16'h0000, 16'hFFDC, 16'h00FD, result_t, result_valid);
        check_result("grazing → blue", 1'b1, 16'h0213,
                     result_valid, result_t);

        // TEST 4: looking up → MISS
        run_intersection(16'h0000, 16'h0033, 16'h00FB, result_t, result_valid);
        check_result("looking up → blue", 1'b0, 16'h0000,
                     result_valid, result_t);

        // =================================================================
        // ORANGE SPHERE: center(-2.75, 0.1, 3.5) r=0.6
        // =================================================================
        $display("");
        $display("--- Orange sphere: center(-2.75, 0.1, 3.5) r=0.6 ---");
        load_sphere(16'hFD40, 16'h001A, 16'h0380, 16'h009A);

        // TEST 5: aimed at orange → HIT t=4.6797 (0x04AE)
        run_intersection(16'hFF7B, 16'hFFF4, 16'h00DA, result_t, result_valid);
        check_result("aimed → orange", 1'b1, 16'h04AE,
                     result_valid, result_t);

        // TEST 6: straight ahead misses orange → MISS
        run_intersection(16'h0000, 16'h0000, 16'h0100, result_t, result_valid);
        check_result("straight ahead → orange", 1'b0, 16'h0000,
                     result_valid, result_t);

        // =================================================================
        // RED SPHERE: center(2.0, -0.2, 4.0) r=0.35
        // =================================================================
        $display("");
        $display("--- Red sphere: center(2.0, -0.2, 4.0) r=0.35 ---");
        load_sphere(16'h0200, 16'hFFCD, 16'h0400, 16'h005A);

        // TEST 7: far right → MISS
        run_intersection(16'h00CD, 16'h0000, 16'h009A, result_t, result_valid);
        check_result("far right → red", 1'b0, 16'h0000,
                     result_valid, result_t);

        // TEST 8: behind camera → MISS
        run_intersection(16'h0000, 16'h0000, 16'hFF00, result_t, result_valid);
        check_result("behind camera → red", 1'b0, 16'h0000,
                     result_valid, result_t);

        // =================================================================
        // Summary
        // =================================================================
        $display("");
        $display("================================================================");
        $display("  RESULTS: %0d PASS  %0d FAIL  out of 8 tests",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");
        $display("================================================================");
        $display("");

        $finish;
    end

endmodule
