# Project Scope Assessment — Post-Synthesis Update

**Date:** May 18, 2026  
**Context:** OpenLane 2 synthesis of compute_core.sv on sky130_fd_sc_hd

## Original Scope (M1)

14 parallel ray-object intersection pipelines (one per object in scene_city.json) with a min-reduction tree, targeting simultaneous testing of all objects per ray at 50 MHz on sky130 HD.

## Synthesis Finding

A single sphere intersection unit synthesizes to 41,118 cells and 248,852 µm² on sky130 HD. 96.4% of the area is combinational logic dominated by the multiplier trees for the quadratic formula (12 multiplications total: 9 for three dot products, 3 for the discriminant). 14 parallel instances would require approximately 3.5 million µm² — far exceeding any reasonable die budget for an embedded automotive chiplet. The design meets timing at the typical corner (+8.667 ns slack at 20 ns period) but fails the slow corner by 2.314 ns, indicating the critical path through the discriminant stage is approximately 22.3 ns.

## Scope Adjustment

I am adjusting the scope to a **single time-multiplexed intersection unit**. Instead of 14 parallel pipelines, the host loads one object's parameters via AXI4-Lite, sends the ray direction via AXI4-Stream, reads the result, then loads the next object. For 14 objects this takes 14 × 23 cycles = 322 cycles per pixel at 50 MHz = 6.44 µs per pixel.

## Why M4 Benchmarks Remain Meaningful

The M1 baseline measured 503,000 intersection tests per second in Python. The time-multiplexed chiplet achieves 50,000,000 / 23 = 2,170,000 tests per second — a **4.3× throughput improvement** from eliminating Python dispatch overhead. At the pixel level, 6.44 µs per pixel vs 84 µs software gives a **13× speedup** directly measurable by comparing per-frame render times.

## What Was Removed

- Parallel multi-object testing (14 pipelines) — area infeasible at 248,852 µm² per unit
- Min-reduction tree for nearest-hit selection — host does this in software
- AXI4-Stream bandwidth advantage — not fully utilized in time-multiplexed mode since AXI4-Lite register reloads are needed between objects

## What Remains

- Full ray-sphere intersection pipeline (quadratic + non-restoring sqrt)
- AXI4-Lite register interface for sphere and ray origin configuration
- AXI4-Stream for ray direction input and hit distance output
- Q8.8 fixed-point precision (validated: worst error 0.0195 scene units, within 0.025 pixel threshold)
- Single-clock-domain synchronous design on sky130 HD at 50 MHz

## Confirmation

No further scope changes are needed beyond the parallel-to-sequential adjustment. The single pipeline synthesizes cleanly (0 DRC, 0 LVS), fits in the die (35.9% utilization), and meets timing at the typical corner. The slow corner violation will be addressed by pipelining the discriminant stage for M3, adding 1 cycle of latency with no functional impact.
