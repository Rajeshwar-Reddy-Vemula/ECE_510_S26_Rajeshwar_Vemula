# Critical Path Analysis

## Identification

The critical path runs from the **b_coeff register** (output of the STAGE_DOTS
pipeline stage) through the **discriminant calculation** (`b*b - 4*a*c`) to the
**disc register** (input of SQRT_INIT stage).

Specifically:
- **Start point:** `b_coeff` register (32-bit signed, Q16.16), latched at the
  end of STAGE_DOTS
- **End point:** `disc` register (64-bit signed, Q32.32), latched at the end
  of STAGE_DISC
- **Logic stages:** Two 32×32 signed multiplications (`b*b` and `a*c`), one
  64-bit subtraction, and one 64-bit multiplication by the constant 4

## Why This Is the Critical Path

The discriminant calculation `disc = b*b - 4*a*c` requires two full 32-bit
multiplications in a single clock cycle. On sky130 HD standard cells, a 32×32
multiplier is synthesized as a tree of full adders and partial product
generators — approximately 1,000 gates deep with a propagation delay of
~11 ns. Two multiplications plus a 64-bit subtraction chain to ~22 ns total,
which exceeds the 20 ns clock period at the slow corner.

At the typical corner (tt, 25°C, 1.80V), the path has +8.67 ns slack —
comfortably within budget. At the slow corner (ss, 100°C, 1.60V), gate delays
increase by approximately 2× and the path fails by 2.31 ns, giving an actual
path delay of 22.31 ns.

The dominant cell types along this path are:
- `sky130_fd_sc_hd__nand2_*` and `sky130_fd_sc_hd__xnor2_*` — multiplier
  partial product and carry logic
- `sky130_fd_sc_hd__a22oi_*` — mux-style reduction in the adder tree
- `sky130_fd_sc_hd__nor2_*` — final subtraction carry chain
- `sky130_fd_sc_hd__buf_*` — timing repair buffers inserted by OpenROAD (2,434
  total) to reduce fanout on high-load nets

## What Would Shorten It

1. **Pipeline the discriminant:** Split STAGE_DISC into two cycles — STAGE_BSQ
   (`b_sq = b*b`) and STAGE_DISC (`disc = b_sq - 4*a*c`). This halves the
   combinational depth from two multiplications to one, bringing the critical
   path to ~12 ns and clearing the slow corner with margin.

2. **Reduce operand width:** Using Q4.12 instead of Q8.8 would narrow the
   intermediate products from 32-bit to 24-bit, reducing multiplier area and
   delay by approximately 40%. The tradeoff is reduced integer range (±8
   instead of ±128).

3. **Target a slower clock:** Running at 25 MHz (40 ns period) gives 17.7 ns
   of slack at the slow corner, eliminating all setup violations with no RTL
   changes. Throughput drops from 2.17M to 1.09M tests/sec — still a 2×
   speedup over the software baseline.
