`timescale 1ns/1ps
// =============================================================================
// Module:      top
// File:        top.sv
// Project:     Ray-Object Intersection Accelerator — ECE 510 HW4AI Spring 2026
// Author:      Rajeshwar Vemula
//
// Description:
//   Integrated top-level module for M3.
//   Instantiates interface_top (AXI4-Lite + AXI4-Stream) and
//   compute_core (ray-sphere intersection pipeline) as separate
//   children and wires them together.
//
// Clock domain: Single clock domain — clk. No clock crossings.
// Reset: Synchronous, active-high.
//
// Hierarchy:
//   top
//   ├── interface_top u_intf  (AXI register file + stream control)
//   └── compute_core  u_core  (ray-sphere intersection + sqrt)
//
// Inter-module wiring (no glue logic — direct connections):
//   interface → compute_core:
//     reg_ray_ox/oy/oz    ray origin from AXI4-Lite registers
//     stream_ray_dx/dy/dz ray direction from AXI4-Stream
//     reg_sph_cx/cy/cz/r  sphere params from AXI4-Lite registers
//     core_start           1-cycle start pulse from stream handshake
//   compute_core → interface:
//     core_hit_distance    Q8.8 hit distance
//     core_hit_valid       1 if ray intersects sphere
//     core_done            1-cycle done pulse
//
// Ports:
//   clk              in  1    System clock 50 MHz
//   rst              in  1    Synchronous active-high reset
//   s_axi_*                   AXI4-Lite slave (control plane)
//   s_axis_*/m_axis_*         AXI4-Stream (data plane)
// =============================================================================

module top (
    input  logic        clk,
    input  logic        rst,

    // AXI4-Lite slave
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // AXI4-Stream slave (ray direction input)
    input  logic [63:0] s_axis_tdata,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,

    // AXI4-Stream master (result output)
    output logic [63:0] m_axis_tdata,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready
);

    // -----------------------------------------------------------------------
    // Inter-module wires
    // -----------------------------------------------------------------------
    logic signed [15:0] reg_ray_ox, reg_ray_oy, reg_ray_oz;
    logic signed [15:0] stream_ray_dx, stream_ray_dy, stream_ray_dz;
    logic signed [15:0] reg_sph_cx, reg_sph_cy, reg_sph_cz, reg_sph_r;
    logic               core_start;
    logic signed [15:0] core_hit_distance;
    logic               core_hit_valid;
    logic               core_done;

    // -----------------------------------------------------------------------
    // interface_top — AXI4-Lite register file + AXI4-Stream control
    // -----------------------------------------------------------------------
    interface_top u_intf (
        .clk             (clk),
        .rst             (rst),

        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awready   (s_axi_awready),
        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wstrb     (s_axi_wstrb),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wready    (s_axi_wready),
        .s_axi_bresp     (s_axi_bresp),
        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bready    (s_axi_bready),
        .s_axi_araddr    (s_axi_araddr),
        .s_axi_arvalid   (s_axi_arvalid),
        .s_axi_arready   (s_axi_arready),
        .s_axi_rdata     (s_axi_rdata),
        .s_axi_rresp     (s_axi_rresp),
        .s_axi_rvalid    (s_axi_rvalid),
        .s_axi_rready    (s_axi_rready),

        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tready   (s_axis_tready),
        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tready   (m_axis_tready),

        .reg_ray_ox      (reg_ray_ox),
        .reg_ray_oy      (reg_ray_oy),
        .reg_ray_oz      (reg_ray_oz),
        .reg_sph_cx      (reg_sph_cx),
        .reg_sph_cy      (reg_sph_cy),
        .reg_sph_cz      (reg_sph_cz),
        .reg_sph_r       (reg_sph_r),
        .stream_ray_dx   (stream_ray_dx),
        .stream_ray_dy   (stream_ray_dy),
        .stream_ray_dz   (stream_ray_dz),
        .core_start      (core_start),

        .core_hit_distance(core_hit_distance),
        .core_hit_valid   (core_hit_valid),
        .core_done        (core_done)
    );

    // -----------------------------------------------------------------------
    // compute_core — ray-sphere intersection pipeline + sqrt
    // -----------------------------------------------------------------------
    compute_core u_core (
        .clk          (clk),
        .rst          (rst),
        .start        (core_start),
        .ray_ox       (reg_ray_ox),
        .ray_oy       (reg_ray_oy),
        .ray_oz       (reg_ray_oz),
        .ray_dx       (stream_ray_dx),
        .ray_dy       (stream_ray_dy),
        .ray_dz       (stream_ray_dz),
        .sph_cx       (reg_sph_cx),
        .sph_cy       (reg_sph_cy),
        .sph_cz       (reg_sph_cz),
        .sph_r        (reg_sph_r),
        .hit_distance (core_hit_distance),
        .hit_valid    (core_hit_valid),
        .done         (core_done)
    );

endmodule
