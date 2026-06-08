// =============================================================================
// Module:      tb_top
// File:        tb_top.sv
// Project:     Ray-Object Intersection Accelerator  ECE 510 HW4AI Spring 2026
//
// Description:
//   End-to-end M4 co-simulation testbench with verbose transaction logging.
//   22 hand-picked test vectors across 3 spheres from scene_city.json.
//   Expected values from Python FP64 / Q8.8 software model.
//   Logs every AXI4-Lite write, AXI4-Stream transfer, and computation phase.
//
// Compile (VCS):
//   vcs -full64 -sverilog -timescale=1ns/1ns \
//       rtl/compute_core.sv rtl/interface_top.sv rtl/top.sv \
//       tb/tb_top.sv -o sim_m3
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

    // DUT
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
    integer start_time, end_time;

    // -----------------------------------------------------------------------
    // AXI4-Lite write  verbose
    // -----------------------------------------------------------------------
    task axi_write(input [31:0] addr, input [31:0] data, input string reg_name);
        $display("  [%0t] AXI4-Lite WRITE: addr=0x%02X data=0x%08X (%s)",
                 $time, addr[7:0], data, reg_name);
        @(negedge clk);
        s_axi_awaddr  = addr;  s_axi_awvalid = 1;
        s_axi_wdata   = data;  s_axi_wvalid  = 1;
        s_axi_wstrb   = 4'hF;  s_axi_bready  = 1;
        @(posedge clk);
        while (!(s_axi_awready && s_axi_wready)) @(posedge clk);
        @(negedge clk);
        s_axi_awvalid = 0; s_axi_wvalid = 0;
        @(posedge clk);
        while (!s_axi_bvalid) @(posedge clk);
        $display("  [%0t] AXI4-Lite BRESP: %s", $time,
                 (s_axi_bresp == 2'b00) ? "OKAY" : "ERROR");
        @(posedge clk);
        @(negedge clk);
        s_axi_bready = 0;
    endtask

    // -----------------------------------------------------------------------
    // Load sphere via AXI4-Lite  verbose
    // -----------------------------------------------------------------------
    task load_sphere(input [15:0] cx, input [15:0] cy,
                     input [15:0] cz, input [15:0] r);
        $display("  [%0t] --- Loading sphere params via AXI4-Lite ---", $time);
        $display("  [%0t]     center=(%0.4f, %0.4f, %0.4f) r=%0.4f",
                 $time,
                 $itor($signed(cx))/256.0,
                 $itor($signed(cy))/256.0,
                 $itor($signed(cz))/256.0,
                 $itor($signed(r))/256.0);
        axi_write(32'h1C, {16'b0, cx}, "SPH_CX");
        axi_write(32'h20, {16'b0, cy}, "SPH_CY");
        axi_write(32'h24, {16'b0, cz}, "SPH_CZ");
        axi_write(32'h28, {16'b0, r},  "SPH_R");
        $display("  [%0t] --- Sphere params loaded ---", $time);
    endtask

    // -----------------------------------------------------------------------
    // Load ray origin via AXI4-Lite  verbose
    // -----------------------------------------------------------------------
    task load_ray_origin(input [15:0] ox, input [15:0] oy, input [15:0] oz);
        $display("  [%0t] --- Loading ray origin via AXI4-Lite ---", $time);
        $display("  [%0t]     origin=(%0.4f, %0.4f, %0.4f)",
                 $time,
                 $itor($signed(ox))/256.0,
                 $itor($signed(oy))/256.0,
                 $itor($signed(oz))/256.0);
        axi_write(32'h04, {16'b0, ox}, "RAY_OX");
        axi_write(32'h08, {16'b0, oy}, "RAY_OY");
        axi_write(32'h0C, {16'b0, oz}, "RAY_OZ");
        $display("  [%0t] --- Ray origin loaded ---", $time);
    endtask

    // -----------------------------------------------------------------------
    // Send ray direction via AXI4-Stream, wait for result  verbose
    // -----------------------------------------------------------------------
    task run_intersection(input [15:0] dx, input [15:0] dy, input [15:0] dz,
                          output [15:0] result_t, output logic result_valid);
        integer timeout;

        $display("  [%0t] AXI4-Stream TX: sending ray direction D=(%0.4f, %0.4f, %0.4f)",
                 $time,
                 $itor($signed(dx))/256.0,
                 $itor($signed(dy))/256.0,
                 $itor($signed(dz))/256.0);
        $display("  [%0t]     tdata=0x%016X  tvalid=1", $time,
                 {16'h0000, dz, dy, dx});

        @(negedge clk);
        s_axis_tdata  = {16'h0000, dz, dy, dx};
        s_axis_tvalid = 1'b1;

        @(posedge clk);
        while (!s_axis_tready) @(posedge clk);
        $display("  [%0t] AXI4-Stream HANDSHAKE: tready=1, ray accepted", $time);
        start_time = $time;
        @(negedge clk);
        s_axis_tvalid = 1'b0;

        $display("  [%0t] COMPUTE: intersection pipeline running...", $time);

        timeout = 0;
        while (!m_axis_tvalid && timeout < 100) begin
            @(posedge clk); timeout++;
        end
        end_time = $time;

        if (m_axis_tvalid) begin
            result_t     = m_axis_tdata[15:0];
            result_valid = 1'b1;
            $display("  [%0t] AXI4-Stream RX: result received after %0d cycles",
                     $time, (end_time - start_time) / 10);
            $display("  [%0t]     tdata=0x%016X  t=0x%04X (%0.4f)",
                     $time, m_axis_tdata, result_t,
                     $itor($signed(result_t))/256.0);
        end else begin
            result_t     = 16'h0000;
            result_valid = 1'b0;
            $display("  [%0t] TIMEOUT: no result after 100 cycles", $time);
        end

        @(negedge clk);
        @(posedge clk);
    endtask

    // -----------------------------------------------------------------------
    // Check result  hit/miss by t value, ±3 LSB tolerance
    // -----------------------------------------------------------------------
    task check_result(input string desc, input logic expect_hit,
                      input [15:0] expect_t, input logic actual_valid,
                      input [15:0] actual_t);
        logic actual_hit, hit_match, t_match;
        actual_hit = ($signed(actual_t) > 16'sd0);
        hit_match  = (actual_hit == expect_hit);
        t_match    = 1;
        if (expect_hit)
            t_match = ($signed(actual_t) >= $signed(expect_t) - 3) &&
                      ($signed(actual_t) <= $signed(expect_t) + 3);

        if (hit_match && t_match) begin
            if (expect_hit)
                $display("  >> PASS  TEST%0d  %s: hit=1 t=0x%04X (%0.4f) exp=0x%04X (%0.4f)  delta=%0d LSB",
                    test_num, desc, actual_t, $itor($signed(actual_t))/256.0,
                    expect_t, $itor($signed(expect_t))/256.0,
                    $signed(actual_t) - $signed(expect_t));
            else
                $display("  >> PASS  TEST%0d  %s: miss (disc<0 or t<=0)", test_num, desc);
            pass_count++;
        end else begin
            $display("  >> FAIL  TEST%0d  %s: hit=%0b(exp %0b) t=0x%04X(exp 0x%04X) delta=%0d LSB",
                test_num, desc, actual_hit, expect_hit, actual_t, expect_t,
                $signed(actual_t) - $signed(expect_t));
            fail_count++;
        end
        test_num++;
        $display("");
    endtask

    // -----------------------------------------------------------------------
    // Main test
    // -----------------------------------------------------------------------
    logic [15:0] result_t;
    logic        result_valid;



  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
    initial begin
        pass_count = 0; fail_count = 0; test_num = 1;
        s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s_axi_arvalid = 0; s_axi_rready = 0;
        s_axi_awaddr  = 0; s_axi_wdata  = 0; s_axi_wstrb  = 0;
        s_axi_araddr  = 0;
        s_axis_tdata  = 0; s_axis_tvalid = 0;
        m_axis_tready = 1;

        $display("");
        $display("[%0t] Asserting synchronous reset (active-high)...", $time);
        rst = 1;
        
        repeat(4) @(posedge clk); #1;
        rst = 0;
        $display("[%0t] Reset released.", $time);
        repeat(4) @(posedge clk); #1;

        $display("");
        $display("================================================================");
        $display("  M3 Co-Simulation  22 Hand-Picked Test Vectors");
        $display("  Protocol: AXI4-Lite (config) + AXI4-Stream (ray data)");
        $display("  Scene: scene_city.json  3 spheres");
        $display("  Reference: Python FP64 intersect_sphere()");
        $display("  Tolerance: +/- 3 LSB Q8.8 (0.012 scene units)");
        $display("  All values in Q8.8 fixed-point (1 LSB = 1/256)");
        $display("================================================================");
        $display("");

        // -----------------------------------------------------------------
        // Load ray origin: (0, 0.35, -1)  same for all tests
        // -----------------------------------------------------------------
        $display("============================================================");
        $display("  Phase 1: Loading ray origin via AXI4-Lite");
        $display("============================================================");
        load_ray_origin(16'h0000, 16'h005A, 16'hFF00);

        // =================================================================
        // BLUE SPHERE
        // =================================================================
        $display("");
        $display("============================================================");
        $display("  Phase 2: Blue sphere  center(0, 0, 1.5) r=0.45");
        $display("  Loading sphere params, then testing 6 rays");
        $display("============================================================");
        load_sphere(16'h0000, 16'h0000, 16'h0180, 16'h0073);

        $display("");
        $display("  --- TEST 1: direct hit (ray aimed at sphere center) ---");
        run_intersection(16'h0000, 16'hFFDD, 16'h00FE, result_t, result_valid);
        check_result("direct hit blue", 1'b1, 16'h0213, result_valid, result_t);

        $display("  --- TEST 2: upper hit (ray aimed above center) ---");
        run_intersection(16'h0000, 16'hFFF3, 16'h0100, result_t, result_valid);
        check_result("upper hit blue", 1'b1, 16'h0220, result_valid, result_t);

        $display("  --- TEST 3: right hit (ray aimed right of center) ---");
        run_intersection(16'h000E, 16'hFFDD, 16'h00FD, result_t, result_valid);
        check_result("right hit blue", 1'b1, 16'h0217, result_valid, result_t);

        $display("  --- TEST 4: grazing hit (ray near sphere edge) ---");
        run_intersection(16'h0029, 16'hFFDD, 16'h00FA, result_t, result_valid);
        check_result("grazing blue", 1'b1, 16'h0249, result_valid, result_t);

        $display("  --- TEST 5: near miss (ray just outside sphere) ---");
        run_intersection(16'h0042, 16'h0020, 16'h00F5, result_t, result_valid);
        check_result("near miss blue", 1'b0, 16'h0000, result_valid, result_t);

        $display("  --- TEST 6: far miss (ray in opposite direction) ---");
        run_intersection(16'h0000, 16'hFFDD, 16'hFF02, result_t, result_valid);
        check_result("far miss blue", 1'b0, 16'h0000, result_valid, result_t);

        // =================================================================
        // ORANGE SPHERE
        // =================================================================
        $display("");
        $display("============================================================");
        $display("  Phase 3: Orange sphere  center(-2.75, 0.1, 3.5) r=0.6");
        $display("  Re-loading sphere params via AXI4-Lite (time-multiplex)");
        $display("============================================================");
        load_sphere(16'hFD40, 16'h001A, 16'h0380, 16'h009A);

        $display("");
        $display("  --- TEST 7: direct hit orange ---");
        run_intersection(16'hFF7B, 16'hFFF4, 16'h00DA, result_t, result_valid);
        check_result("direct hit orange", 1'b1, 16'h04AE, result_valid, result_t);

        $display("  --- TEST 8: upper hit orange ---");
        run_intersection(16'hFF7B, 16'h0002, 16'h00DA, result_t, result_valid);
        check_result("upper hit orange", 1'b1, 16'h04BC, result_valid, result_t);

        $display("  --- TEST 9: right hit orange ---");
        run_intersection(16'hFF81, 16'hFFF4, 16'h00DE, result_t, result_valid);
        check_result("right hit orange", 1'b1, 16'h04B3, result_valid, result_t);

        $display("  --- TEST 10: grazing orange ---");
        run_intersection(16'hFF8F, 16'hFFF3, 16'h00E5, result_t, result_valid);
        check_result("grazing orange", 1'b1, 16'h04E2, result_valid, result_t);

        $display("  --- TEST 11: near miss orange ---");
        run_intersection(16'hFFA0, 16'h0022, 16'h00EB, result_t, result_valid);
        check_result("near miss orange", 1'b0, 16'h0000, result_valid, result_t);

        $display("  --- TEST 12: far miss orange ---");
        run_intersection(16'h0085, 16'hFFEA, 16'hFF26, result_t, result_valid);
        check_result("far miss orange", 1'b0, 16'h0000, result_valid, result_t);

        // =================================================================
        // RED SPHERE
        // =================================================================
        $display("");
        $display("============================================================");
        $display("  Phase 4: Red sphere  center(2.0, -0.2, 4.0) r=0.35");
        $display("  Re-loading sphere params via AXI4-Lite (time-multiplex)");
        $display("============================================================");
        load_sphere(16'h0200, 16'hFFCD, 16'h0400, 16'h005A);

        $display("");
        $display("  --- TEST 13: direct hit red ---");
        run_intersection(16'h005F, 16'hFFE6, 16'h00EC, result_t, result_valid);
        check_result("direct hit red", 1'b1, 16'h0510, result_valid, result_t);

        $display("  --- TEST 14: upper hit red ---");
        run_intersection(16'h005F, 16'hFFEE, 16'h00ED, result_t, result_valid);
        check_result("upper hit red", 1'b1, 16'h051B, result_valid, result_t);

        $display("  --- TEST 15: right hit red ---");
        run_intersection(16'h0063, 16'hFFE6, 16'h00EB, result_t, result_valid);
        check_result("right hit red", 1'b1, 16'h0513, result_valid, result_t);

        $display("  --- TEST 16: grazing red ---");
        run_intersection(16'h006B, 16'hFFE7, 16'h00E7, result_t, result_valid);
        check_result("grazing red", 1'b1, 16'h0534, result_valid, result_t);

        $display("  --- TEST 17: near miss red ---");
        run_intersection(16'h0073, 16'hFFFF, 16'h00E5, result_t, result_valid);
        check_result("near miss red", 1'b0, 16'h0000, result_valid, result_t);

        $display("  --- TEST 18: far miss red ---");
        run_intersection(16'hFFA1, 16'hFFF9, 16'hFF12, result_t, result_valid);
        check_result("far miss red", 1'b0, 16'h0000, result_valid, result_t);

        // =================================================================
        // EDGE CASES
        // =================================================================
        $display("");
        $display("============================================================");
        $display("  Phase 5: Edge cases (blue sphere reloaded)");
        $display("============================================================");
        load_sphere(16'h0000, 16'h0000, 16'h0180, 16'h0073);

        $display("");
        $display("  --- TEST 19: behind camera (ray points backward) ---");
        run_intersection(16'h0000, 16'h0000, 16'hFF00, result_t, result_valid);
        check_result("behind camera", 1'b0, 16'h0000, result_valid, result_t);

        $display("  --- TEST 20: straight up (ray perpendicular to scene) ---");
        run_intersection(16'h0000, 16'h0100, 16'h0000, result_t, result_valid);
        check_result("straight up", 1'b0, 16'h0000, result_valid, result_t);

        $display("  --- TEST 21: straight ahead (canonical test from M2) ---");
        run_intersection(16'h0000, 16'h0000, 16'h0100, result_t, result_valid);
        check_result("straight ahead blue", 1'b1, 16'h0238, result_valid, result_t);

        $display("  --- TEST 22: 45 degrees right (wide miss) ---");
        run_intersection(16'h00B5, 16'h0000, 16'h00B5, result_t, result_valid);
        check_result("45deg right blue", 1'b0, 16'h0000, result_valid, result_t);

        // =================================================================
        // Summary
        // =================================================================
        $display("");
        $display("================================================================");
        $display("  RESULTS: %0d PASS  %0d FAIL  out of 22 tests",
                 pass_count, fail_count);
        $display("  (13 expected hits, 9 expected misses)");
        $display("  Tolerance: +/- 3 LSB Q8.8 = 0.012 scene units");
        $display("  Max acceptable error: 0.025 (1 pixel at 400x300)");
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");
        $display("================================================================");
        $display("");

        $finish;
    end

endmodule
