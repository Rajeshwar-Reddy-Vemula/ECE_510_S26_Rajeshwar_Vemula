# M3 Plan — Changes for Milestone 3

**Synthesis target:** Option A — own project core (compute_core.sv)

The slow-corner setup violation of -2.314 ns is acknowledged but will not be addressed in M3. The design passes at typical (+8.667 ns slack) and fast (+12.646 ns) corners, which is sufficient for functional verification. The M3 focus is **integration and co-simulation**: separating `interface_top` (AXI4-Lite/Stream register file) from `compute_core` (intersection pipeline) and wiring them together in a new `top.sv` module, then demonstrating end-to-end data flow through 22 hand-picked test vectors and 999 randomised tests across all 3 spheres from scene_city.json.

The existing synthesis results from CF07 will be committed directly — the RTL is unchanged, so re-running OpenLane would produce identical results. Total area of 248,852 µm² at 35.9% utilization fits the 850×850 µm die with margin. Power at 33.75 mW is documented for M4 optimization (clock gating during IDLE/SQRT_RUN states). The discriminant pipeline split to fix the slow-corner violation is deferred to M4, where it will also be re-synthesized to confirm timing closure.
