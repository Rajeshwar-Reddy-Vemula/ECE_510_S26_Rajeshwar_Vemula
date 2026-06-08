// =============================================================================
// Module:      compute_core
// File:        compute_core.sv
// Project:     Ray-Object Intersection Accelerator — ECE 510 HW4AI Spring 2026
// Author:      Rajeshwar Vemula
//
// Description:
//   Fixed-function ray-sphere intersection pipeline.
//   Q8.8 fixed-point arithmetic (INT16, 8 integer + 8 fractional bits).
//   Square root via embedded non-restoring integer algorithm (no submodule).
//
//   M4 change from M3: STAGE_DISC split into STAGE_MUL + STAGE_DISC to
//   fix slow-corner setup violation (-2.314 ns at max_ss_100C_1v60).
//   Each stage now has one 32x32 multiply (~12 ns) instead of two (~22 ns).
//
// Clock domain: Single clock domain — clk. No clock crossings.
// Reset: Synchronous, active-high.
//
// Fixed-point formats:
//   Q8.8   — 16-bit signed. 1 LSB = 1/256.  Range -128 to +127.996
//   Q16.16 — 32-bit signed. Product of two Q8.8. 1 LSB = 1/65536
//   Q32.32 — 64-bit signed. Product of two Q16.16. Used for discriminant.
//
// Algorithm (ray-sphere quadratic):
//   OS   = O - S
//   a    = dot(D,D)           [Q16.16]
//   b    = 2*dot(D,OS)        [Q16.16]
//   c    = dot(OS,OS) - R*R   [Q16.16]
//   b_sq = b * b              [Q32.32]  ← NEW pipeline stage
//   ac   = a * c              [Q32.32]  ← NEW pipeline stage
//   disc = b_sq - 4*ac        [Q32.32]
//   sqrt_disc = sqrt(disc[47:16])  [Q8.8]
//   t    = (-b - sqrt_disc<<8) >> 9  [Q8.8]
//   hit  = disc>=0 AND t>0
//
// FSM: IDLE→STAGE_OS→STAGE_DOTS→STAGE_MUL→STAGE_DISC→SQRT_INIT→SQRT_RUN→STAGE_T→DONE
// Latency: 24 clock cycles start to done at 50 MHz (was 23 in M3)
//
// Ports:
//   clk          in  1   System clock 50 MHz
//   rst          in  1   Synchronous active-high reset
//   start        in  1   Pulse high 1 cycle to begin
//   ray_ox/oy/oz in  16  Ray origin, Q8.8 signed
//   ray_dx/dy/dz in  16  Ray direction, Q8.8 signed (normalised)
//   sph_cx/cy/cz in  16  Sphere center, Q8.8 signed
//   sph_r        in  16  Sphere radius, Q8.8 signed (positive)
//   hit_distance out 16  Hit distance t Q8.8 (valid when done=1 hit_valid=1)
//   hit_valid    out 1   1 if ray hits sphere (disc>=0 and t>0)
//   done         out 1   1-cycle pulse when result ready
// =============================================================================

module compute_core (
    input  logic                clk,
    input  logic                rst,
    input  logic                start,

    input  logic signed [15:0]  ray_ox, ray_oy, ray_oz,
    input  logic signed [15:0]  ray_dx, ray_dy, ray_dz,
    input  logic signed [15:0]  sph_cx, sph_cy, sph_cz,
    input  logic signed [15:0]  sph_r,

    output logic signed [15:0]  hit_distance,
    output logic                hit_valid,
    output logic                done
);

    // -----------------------------------------------------------------------
    // FSM states — 4 bits needed for 9 states (was 3 bits / 8 states in M3)
    // -----------------------------------------------------------------------
    typedef enum logic [3:0] {
        IDLE       = 4'd0,
        STAGE_OS   = 4'd1,
        STAGE_DOTS = 4'd2,
        STAGE_MUL  = 4'd3,   // NEW: b_sq = b*b, ac = a*c (one multiply each)
        STAGE_DISC = 4'd4,   // NOW: disc = b_sq - 4*ac (shift + subtract only)
        SQRT_INIT  = 4'd5,
        SQRT_RUN   = 4'd6,
        STAGE_T    = 4'd7,
        DONE_STATE = 4'd8
    } state_t;

    state_t state;

    // -----------------------------------------------------------------------
    // Latched inputs
    // -----------------------------------------------------------------------
    logic signed [15:0] r_ox, r_oy, r_oz;
    logic signed [15:0] r_dx, r_dy, r_dz;
    logic signed [15:0] s_cx, s_cy, s_cz, s_r;

    // -----------------------------------------------------------------------
    // Intersection intermediates
    // -----------------------------------------------------------------------
    logic signed [15:0] os_x, os_y, os_z;      // O-S, Q8.8
    logic signed [31:0] a_coeff;               // dot(D,D),       Q16.16
    logic signed [31:0] b_coeff;               // 2*dot(D,OS),    Q16.16
    logic signed [31:0] c_coeff;               // dot(OS,OS)-R*R, Q16.16
    logic signed [63:0] b_sq;                  // b*b,            Q32.32  (NEW)
    logic signed [63:0] ac_prod;               // a*c,            Q32.32  (NEW)
    logic signed [63:0] disc;                  // b_sq - 4*ac,    Q32.32

    // -----------------------------------------------------------------------
    // Embedded non-restoring sqrt
    // -----------------------------------------------------------------------
    localparam SQRT_W    = 32;
    localparam SQRT_ITERS = SQRT_W >> 1;   // 16

    logic [SQRT_W-1:0]   sq_x;
    logic [SQRT_W-1:0]   sq_q;
    logic [SQRT_W+1:0]   sq_ac;
    logic [4:0]          sq_iter;
    logic [SQRT_W-1:0]   sqrt_result;

    // Combinational next-state for sqrt
    logic [SQRT_W-1:0]   sq_x_next;
    logic [SQRT_W-1:0]   sq_q_next;
    logic [SQRT_W+1:0]   sq_ac_next;
    logic [SQRT_W+1:0]   sq_test;

    always_comb begin
        sq_ac_next = {sq_ac[SQRT_W-1:0], sq_x[SQRT_W-1:SQRT_W-2]};
        sq_x_next  = {sq_x[SQRT_W-3:0], 2'b00};
        sq_test    = sq_ac_next - {sq_q, 2'b01};
        if (!sq_test[SQRT_W+1]) begin
            sq_ac_next = sq_test;
            sq_q_next  = {sq_q[SQRT_W-2:0], 1'b1};
        end else begin
            sq_q_next  = {sq_q[SQRT_W-2:0], 1'b0};
        end
    end

    // -----------------------------------------------------------------------
    // t calculation — combinational from sqrt_result
    // -----------------------------------------------------------------------
    logic signed [31:0]  sqrt_q16;
    logic signed [31:0]  t0_num;
    logic signed [15:0]  t0;

    always_comb begin
        sqrt_q16 = $signed({{8{sqrt_result[15]}},
                             sqrt_result[15:0], 8'b0});
        t0_num   = (-b_coeff) - sqrt_q16;
        t0       = t0_num[24:9];
    end

    // -----------------------------------------------------------------------
    // Main FSM
    // -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state        <= IDLE;
            done         <= 1'b0;
            hit_valid    <= 1'b0;
            hit_distance <= 16'sd0;
            r_ox <= '0; r_oy <= '0; r_oz <= '0;
            r_dx <= '0; r_dy <= '0; r_dz <= '0;
            s_cx <= '0; s_cy <= '0; s_cz <= '0; s_r <= '0;
            os_x <= '0; os_y <= '0; os_z <= '0;
            a_coeff <= '0; b_coeff <= '0; c_coeff <= '0;
            b_sq     <= '0; ac_prod <= '0;
            disc    <= '0;
            sq_x    <= '0; sq_q <= '0; sq_ac <= '0;
            sq_iter <= '0; sqrt_result <= '0;

        end else begin
            done <= 1'b0;

            case (state)

                // -----------------------------------------------------------
                IDLE: begin
                    if (start) begin
                        r_ox <= ray_ox; r_oy <= ray_oy; r_oz <= ray_oz;
                        r_dx <= ray_dx; r_dy <= ray_dy; r_dz <= ray_dz;
                        s_cx <= sph_cx; s_cy <= sph_cy; s_cz <= sph_cz;
                        s_r  <= sph_r;
                        state <= STAGE_OS;
                    end
                end

                // -----------------------------------------------------------
                // Cycle 1: OS = O - S  (Q8.8)
                // -----------------------------------------------------------
                STAGE_OS: begin
                    os_x  <= r_ox - s_cx;
                    os_y  <= r_oy - s_cy;
                    os_z  <= r_oz - s_cz;
                    state <= STAGE_DOTS;
                end

                // -----------------------------------------------------------
                // Cycle 2: dot products (Q8.8*Q8.8 → Q16.16)
                // -----------------------------------------------------------
                STAGE_DOTS: begin
                    a_coeff <= (r_dx * r_dx) + (r_dy * r_dy) + (r_dz * r_dz);
                    b_coeff <= ((r_dx * os_x) + (r_dy * os_y) +
                                (r_dz * os_z)) <<< 1;
                    c_coeff <= ((os_x * os_x) + (os_y * os_y) +
                                (os_z * os_z)) - (s_r * s_r);
                    state   <= STAGE_MUL;
                end

                // -----------------------------------------------------------
                // Cycle 3 (NEW): multiply b*b and a*c separately
                // Each is one 32x32 multiply — half the combinational depth
                // of the original STAGE_DISC which had both in one cycle.
                // Critical path: ~12 ns (one multiplier) vs ~22 ns (two)
                // -----------------------------------------------------------
                STAGE_MUL: begin
                    b_sq    <= $signed({{32{b_coeff[31]}}, b_coeff}) *
                               $signed({{32{b_coeff[31]}}, b_coeff});
                    ac_prod <= $signed({{32{a_coeff[31]}}, a_coeff}) *
                               $signed({{32{c_coeff[31]}}, c_coeff});
                    state   <= STAGE_DISC;
                end

                // -----------------------------------------------------------
                // Cycle 4: disc = b_sq - 4*ac  (shift + subtract only)
                // No multiplier in this stage — just a 2-bit left shift
                // and a 64-bit subtraction. Critical path: ~4 ns.
                // -----------------------------------------------------------
                STAGE_DISC: begin
                    disc  <= b_sq - (ac_prod <<< 2);
                    state <= SQRT_INIT;
                end

                // -----------------------------------------------------------
                // Cycle 5: check sign of disc, initialise sqrt
                // -----------------------------------------------------------
                SQRT_INIT: begin
                    if (disc[63]) begin
                        hit_valid    <= 1'b0;
                        hit_distance <= 16'sd0;
                        done         <= 1'b1;
                        state        <= IDLE;
                    end else begin
                        sq_x    <= disc[47:16];
                        sq_q    <= '0;
                        sq_ac   <= '0;
                        sq_iter <= '0;
                        state   <= SQRT_RUN;
                    end
                end

                // -----------------------------------------------------------
                // Cycles 6-21: 16 sqrt iterations
                // -----------------------------------------------------------
                SQRT_RUN: begin
                    sq_x    <= sq_x_next;
                    sq_ac   <= sq_ac_next;
                    sq_q    <= sq_q_next;

                    if (sq_iter == 5'd15) begin
                        sqrt_result <= sq_q_next;
                        state       <= STAGE_T;
                    end else begin
                        sq_iter <= sq_iter + 5'd1;
                    end
                end

                // -----------------------------------------------------------
                // Cycle 22: let sqrt_result settle for combinational t0
                // -----------------------------------------------------------
                STAGE_T: begin
                    state <= DONE_STATE;
                end

                // -----------------------------------------------------------
                // Cycle 23: latch output, assert done
                // -----------------------------------------------------------
                DONE_STATE: begin
                    if (t0 > 16'sd0) begin
                        hit_distance <= t0;
                        hit_valid    <= 1'b1;
                    end else begin
                        hit_distance <= 16'sd0;
                        hit_valid    <= 1'b0;
                    end
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
