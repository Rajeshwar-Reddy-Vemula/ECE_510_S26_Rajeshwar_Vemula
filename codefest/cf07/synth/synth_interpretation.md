# Synthesis Interpretation — compute_core on sky130_fd_sc_hd

**Tool:** OpenLane 2.3.10 via Docker (ghcr.io/efabless/openlane2:2.3.1)  
**PDK:** sky130_fd_sc_hd  
**Run:** RUN_2026-05-18_05-54-50

## Clock Period and Worst-Case Slack

The design was synthesized with a 20 ns clock period (50 MHz) on the `clk` port. At the typical corner (nom_tt_025C_1v80), setup worst slack is **+8.667 ns** — the design passes comfortably with 11.333 ns of actual path delay. At the slow corner (max_ss_100C_1v60), setup worst negative slack is **-2.314 ns** with 65 violating paths and a total negative slack of -24.866 ns. This means the critical path at the slow corner takes 22.314 ns, exceeding the 20 ns period. The fast corner (max_ff_n40C_1v95) passes with +12.646 ns slack. All hold checks pass at every corner with zero violations; the tightest hold slack is +0.106 ns at the fast corner.

## Critical Path

The post-PNR STA report identifies the critical path as starting at flip-flop **`_56034_`** (a `sky130_fd_sc_hd__dfxtp_1`) and ending at flip-flop **`_56006_`** (also `dfxtp_1`). These correspond to the `b_coeff` register (output of STAGE_DOTS) and the `disc` register (output of STAGE_DISC) in the compute_core FSM. The path traverses the discriminant calculation `disc = b*b - 4*a*c`, which requires two 32×32 signed multiplications and a 64-bit subtraction in a single cycle. The dominant cell types along this path are `sky130_fd_sc_hd__nand2_*` and `sky130_fd_sc_hd__xnor2_*` (partial product generation and carry logic in the synthesized multiplier), `sky130_fd_sc_hd__a22oi_*` (AND-OR-INVERT for adder tree reduction), `sky130_fd_sc_hd__nor2_*` (subtraction carry chain), and `sky130_fd_sc_hd__buf_*` (timing repair buffers inserted by OpenROAD — 2,434 total across the design). The clock tree uses 135 clock buffers and 69 clock inverters, with worst clock skew of 0.654 ns at the slow corner.

## Total Cell Area and Top Three Contributors

Total cell area from metrics.csv is **248,852 µm²** (post-optimization) mapped to **41,118 standard cells** at 35.9% utilization on an 850×850 µm die. The Yosys pre-optimization area is 284,447 µm² with 28,466 cells. The top three contributors by instance count are:

1. **XNOR2 gates** (`sky130_fd_sc_hd__xnor2_2`): 3,286 instances — these form the core of the multiplier partial product and carry-save adder trees used in the 9 dot-product multiplications and 3 discriminant multiplications.
2. **NAND2 gates** (`sky130_fd_sc_hd__nand2_2`): 2,691 instances — used in the multiplier reduction tree and the carry-propagate logic of the 64-bit subtraction.
3. **NOR2 gates** (`sky130_fd_sc_hd__nor2_2`): 2,148 instances — used in the final subtraction carry chains and the sqrt comparison logic.

Sequential elements (479 `dfxtp_2` flip-flops) account for only 10,189 µm² (3.58% of area). The remaining 96.4% is combinational, dominated by the multiplier trees.

## Failed Constraints and Warnings

**Setup timing fails at the slow corner.** 65 paths violate setup at `max_ss_100C_1v60` with worst slack of -2.314 ns. The design would need either a 23 ns clock period (43.5 MHz) to close timing at all corners, or the discriminant stage must be split into two pipeline stages. **All hold checks pass** at every corner with zero violations. There are 446 Verilator lint warnings, primarily `TIMESCALEMOD` (timescale mismatch between the design and sky130 cell models — cosmetic, not functional) and `UNUSEDSIGNAL` (unused bits of `disc[62:48,15:0]`, `sq_ac[33:32]`, `sqrt_result[31:16]`, and `t0_num[31:25,8:0]` — expected since only specific bit ranges are used in the Q8.8 pipeline). There are 43 max-fanout violations and 8 max-capacitance violations across corners, addressed by the 2,434 timing repair buffers OpenROAD inserted. No latches were inferred (latch count = 0). DRC passed with 0 violations. LVS passed with 0 net/device/property differences.
