// =============================================================================
// Module:      compute_core
// File:        compute_core.sv
// Project:     Ray-Object Intersection Accelerator — ECE 510 HW4AI Spring 2026
//
// Description:
//   Fixed-function ray-sphere intersection pipeline.
//   Q8.8 fixed-point arithmetic (INT16, 8 integer + 8 fractional bits).
//   Square root via embedded non-restoring integer algorithm.
//
// Clock domain: Single clock domain — clk.
// Reset: Synchronous, active-high.
// =============================================================================

`timescale 1ns/1ps

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
    // FSM states
    // -----------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE       = 3'd0,
        STAGE_OS   = 3'd1,
        STAGE_DOTS = 3'd2,
        STAGE_DISC = 3'd3,
        SQRT_INIT  = 3'd4,
        SQRT_RUN   = 3'd5,
        STAGE_T    = 3'd6,
        DONE_STATE = 3'd7
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
    logic signed [15:0] os_x, os_y, os_z;      
    logic signed [31:0] a_coeff;               
    logic signed [31:0] b_coeff;               
    logic signed [31:0] c_coeff;               
    logic signed [63:0] disc;                  

    // -----------------------------------------------------------------------
    // Embedded non-restoring sqrt
    // -----------------------------------------------------------------------
    localparam SQRT_W    = 32;

    logic [SQRT_W-1:0]   sq_x;
    logic [SQRT_W-1:0]   sq_q;
    logic [SQRT_W+1:0]   sq_ac;
    logic [4:0]          sq_iter;          
    logic [SQRT_W-1:0]   sqrt_result;      

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
    // t calculation
    // Computes both t0 (nearest hit) and t1 (inside wall hit)
    // -----------------------------------------------------------------------
    logic signed [31:0]  sqrt_q16;     
    logic signed [31:0]  t0_num, t1_num;       
    logic signed [15:0]  t0, t1;           

    always_comb begin
        sqrt_q16 = $signed({{8{sqrt_result[15]}}, sqrt_result[15:0], 8'b0});
        
        t0_num   = (-b_coeff) - sqrt_q16;
        t1_num   = (-b_coeff) + sqrt_q16;
        
        t0       = t0_num[24:9];
        t1       = t1_num[24:9];
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
            disc    <= '0;
            sq_x    <= '0; sq_q <= '0; sq_ac <= '0;
            sq_iter <= '0; sqrt_result <= '0;

        end else begin
            done <= 1'b0;   

            case (state)
                IDLE: begin
                    if (start) begin
                        r_ox <= ray_ox; r_oy <= ray_oy; r_oz <= ray_oz;
                        r_dx <= ray_dx; r_dy <= ray_dy; r_dz <= ray_dz;
                        s_cx <= sph_cx; s_cy <= sph_cy; s_cz <= sph_cz;
                        s_r  <= sph_r;
                        state <= STAGE_OS;
                    end
                end

                STAGE_OS: begin
                    os_x  <= r_ox - s_cx;
                    os_y  <= r_oy - s_cy;
                    os_z  <= r_oz - s_cz;
                    state <= STAGE_DOTS;
                end

                STAGE_DOTS: begin
                    a_coeff <= (r_dx * r_dx) + (r_dy * r_dy) + (r_dz * r_dz);
                    b_coeff <= ((r_dx * os_x) + (r_dy * os_y) + (r_dz * os_z)) <<< 1;
                    c_coeff <= ((os_x * os_x) + (os_y * os_y) + (os_z * os_z)) - (s_r * s_r);
                    state   <= STAGE_DISC;
                end

                STAGE_DISC: begin
                    disc  <= ($signed({{32{b_coeff[31]}}, b_coeff}) *
                              $signed({{32{b_coeff[31]}}, b_coeff}))
                           - (64'sd4 *
                              $signed({{32{a_coeff[31]}}, a_coeff}) *
                              $signed({{32{c_coeff[31]}}, c_coeff}));
                    state <= SQRT_INIT;
                end

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

                STAGE_T: begin
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    if (t0 > 16'sd0) begin
                        hit_distance <= t0;
                        hit_valid    <= 1'b1;
                    end else if (t1 > 16'sd0) begin
                        hit_distance <= t1;
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
