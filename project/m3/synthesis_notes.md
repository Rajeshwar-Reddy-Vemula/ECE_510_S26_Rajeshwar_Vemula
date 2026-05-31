# Synthesis Notes — Milestone 3

**Author:** Rajeshwar Vemula  
**Date:** May 24, 2026  
**Tool:** OpenLane 2.3.10 via Docker (ghcr.io/efabless/openlane2:2.3.1)  
**PDK:** sky130_fd_sc_hd  
**Clock target:** 20 ns (50 MHz)

---

## What Synthesized Successfully

The `compute_core` module — containing the full ray-sphere intersection
pipeline with embedded non-restoring square root — synthesized through the
complete OpenLane 2 flow from RTL to GDS. All 78 OpenLane stages completed
without flow errors. The design passed DRC (0 violations), LVS (0 net/device
differences), and XOR checks (0 differences between Magic and KLayout
outputs). The final GDS was generated cleanly.

The Yosys synthesis stage mapped the design to 28,466 standard cells before
physical optimization. After placement, CTS, and routing, OpenROAD expanded
this to 41,118 cells (including 2,434 timing repair buffers, 135 clock
buffers, 69 clock inverters, 52,340 fill cells, and 9,792 tap cells). The
total cell area is 248,852 µm² on an 850×850 µm die at 35.9% utilization.

The Yosys stat report shows the design area as 284,446 µm², of which only
10,188 µm² (3.58%) is used for sequential elements (479 flip-flops). The
remaining 96.42% is combinational logic, dominated by the multiplier trees
required for the ray-sphere quadratic formula.

## What Did Not Meet Constraints

The design fails setup timing at the slow process corner (ss, 100°C, 1.60V).
The post-PNR STA report (`54-openroad-stapostpnr/max_ss_100C_1v60/max.rpt`)
shows the worst setup path starting at flip-flop `_56034_` and ending at
flip-flop `_56006_`, with a worst negative slack (WNS) of -2.314 ns. Across
all process corners, 65 total setup violations exist, all concentrated in the
slow-slow corners. The total negative slack (TNS) at the worst corner is
-24.866 ns, spread across 33 violating paths.

The typical corner (tt, 25°C, 1.80V) passes setup with +8.667 ns of positive
slack. The fast corner (ff, -40°C, 1.95V) passes with +12.646 ns of slack.
This means the design functions correctly at typical and fast operating
conditions but would fail timing at the worst-case slow corner.

All hold checks pass at all corners with zero violations. The worst hold
slack is +0.106 ns at the fast corner, which is positive and safe. OpenROAD
inserted 101 hold buffers during optimization to ensure hold closure.

The critical path runs through the discriminant calculation stage
(STAGE_DISC in the FSM), where two 32-bit signed multiplications (`b*b` and
`a*c`) and a 64-bit subtraction are computed in a single clock cycle. The
post-PNR timing report confirms the path passes through multiple levels of
`sky130_fd_sc_hd__nand2`, `sky130_fd_sc_hd__xnor2`, and
`sky130_fd_sc_hd__a22oi` cells — these are the partial product generators
and carry propagation logic of the synthesized multiplier. On sky130 HD cells
at the slow corner, this combinational depth produces approximately 22.3 ns
of delay, exceeding the 20 ns clock period by 2.3 ns.

## Power Analysis

The post-PNR power report (`54-openroad-stapostpnr/nom_tt_025C_1v80/power.rpt`)
shows total power of 33.75 mW at 50 MHz at the typical corner:

| Component      | Power (mW) | Percentage |
|----------------|-----------|------------|
| Combinational  | 30.948    | 91.7%      |
| Sequential     | 1.203     | 3.6%       |
| Clock network  | 1.602     | 4.7%       |
| **Total**      | **33.753**| **100%**   |

Internal power accounts for 42.6% and switching power for 57.4%. Leakage
is negligible at 0.17 µW. The design is dominated by combinational switching
in the multiplier trees, which is expected given that 96.4% of the cell area
is combinational logic.

This exceeds the original M1 target of 2 mW. The M1 estimate was based on
an assumed 640 cells; the actual design is 28,466 cells (Yosys) — 44× larger
than originally estimated. The discrepancy comes from underestimating the
gate count of synthesized 16×16 signed multipliers on sky130 HD. Each
multiplier synthesizes to approximately 2,000-3,000 gates, and the design
contains 12 multiplications in the quadratic formula.

## Scope Adjustment

The original M1 plan called for 14 parallel intersection pipelines — one per
object in the scene. With a single pipeline occupying 284,446 µm² of Yosys
area, 14 parallel instances would require approximately 4 million µm² before
physical optimization. This is not feasible for an embedded automotive
chiplet.

The adjusted scope is a single intersection unit operating in
time-multiplexed mode. The host loads one object's parameters via AXI4-Lite,
sends the ray direction via AXI4-Stream, reads the result, then loads the
next object. For 14 objects this takes 14 × 23 cycles = 322 cycles per pixel
at 50 MHz = 6.44 µs per pixel, compared to the software baseline of 84 µs
per pixel (14 objects × 6 µs Python dispatch overhead per test). This still
delivers a meaningful speedup while fitting in a single 850×850 µm die.

## What Was Removed

- Parallel multi-object testing (14 simultaneous pipelines)
- Min-reduction tree for nearest-hit selection among parallel testers
- AXI4-Stream as the sole data plane — while implemented and functional, the
  bandwidth advantage is not fully utilized in time-multiplexed mode since
  each test requires AXI4-Lite register reloads between objects

## What Remains

- Full ray-sphere intersection pipeline with quadratic solver and sqrt
- AXI4-Lite register interface for sphere and ray origin configuration
- AXI4-Stream for ray direction input and hit distance output
- Q8.8 fixed-point precision (validated against FP64 reference, 22/22 pass)
- Single-clock-domain synchronous design on sky130 HD
- Complete RTL-to-GDS flow passing DRC and LVS

## Looking Ahead to M4

For M4 the focus will be on benchmarking the existing design against the
M1 software baseline rather than attempting major architectural changes.
The primary deliverable will be comparing the hardware throughput
(cycles per intersection at 50 MHz) against the measured Python throughput
(503,000 tests/sec from M1 profiling) to quantify the actual speedup.

If time permits, clock gating could be explored to reduce the 33.75 mW
power figure — the multiplier trees are idle during the 16-cycle sqrt
phase and during IDLE, so gating the clock to combinational logic during
those states could reduce average power. However this is not a commitment
for M4 and depends on remaining schedule.

The slow-corner timing violation (-2.314 ns) could be addressed by
targeting a slower clock (25 MHz would give 17.7 ns of margin) or by
accepting that the design operates correctly at typical conditions,
which is standard practice for prototype silicon where worst-case corner
sign-off is not required.
