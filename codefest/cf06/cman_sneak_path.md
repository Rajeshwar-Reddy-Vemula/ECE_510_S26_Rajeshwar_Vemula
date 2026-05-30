# CMAN — Sneak Paths in a 2×2 Resistive Crossbar

## Circuit Setup

A 2×2 resistive crossbar with fixed cell resistances:

| Cell      | Resistance | State |
|-----------|------------|-------|
| R[0][0]   | 1 kΩ       | on    |
| R[0][1]   | 2 kΩ       | off   |
| R[1][0]   | 2 kΩ       | off   |
| R[1][1]   | 1 kΩ       | on    |

- Low-resistance cells (1 kΩ) → "on" weights
- High-resistance cells (2 kΩ) → "off" weights
- Rows carry input voltages; columns carry output currents
- Column 0 is held at virtual ground (0 V) by a transimpedance amplifier for current sensing

## (a) Ideal Read

**Conditions:** V_row0 = 1 V, V_row1 = 0 V (grounded), V_col0 = 0 V (virtual ground), V_col1 = 0 V (grounded).

When all unselected lines are actively driven to ground, only the cell at the intersection of the driven row and the sensed column carries current into the column-0 sense node. All other paths terminate at ground without contributing to the column-0 current.

**Calculation:**

$$
I_{col0}^{ideal} = \frac{V_{row0} - V_{col0}}{R[0][0]} = \frac{1\text{ V} - 0\text{ V}}{1\text{ k}\Omega}
$$

$$
\boxed{I_{col0}^{ideal} = 1.000 \text{ mA}}
$$

This is the **intended MVM result** for the input vector [1 V, 0 V] dotted with the column-0 weight column [G₀₀, G₁₀] = [1 mS, 0.5 mS]: only the row-0 contribution matters because row 1 is held at 0 V.

---

## (b) KCL Solution for Floating Nodes

**Conditions:** V_row0 = 1 V, V_col0 = 0 V (virtual ground), V_row1 = ? (floating), V_col1 = ? (floating).

A floating node has **no external path to source or sink current**, so by KCL the algebraic sum of currents leaving the node through all connected resistors must equal zero.

Let:
- V₁ = V_row1
- V₂ = V_col1

### KCL at node V_row1

Two resistors connect to V_row1:
- R[1][0] = 2 kΩ → connects V_row1 to V_col0 (= 0 V)
- R[1][1] = 1 kΩ → connects V_row1 to V_col1 (= V₂)

Sum of currents *leaving* V_row1 = 0:

$$
\frac{V_1 - 0}{2\text{ k}\Omega} + \frac{V_1 - V_2}{1\text{ k}\Omega} = 0
$$

Multiply through by 2 kΩ:

$$
V_1 + 2(V_1 - V_2) = 0
$$

$$
\boxed{3 V_1 - 2 V_2 = 0} \quad \text{...(1)}
$$

### KCL at node V_col1

Two resistors connect to V_col1:
- R[0][1] = 2 kΩ → connects V_col1 to V_row0 (= 1 V)
- R[1][1] = 1 kΩ → connects V_col1 to V_row1 (= V₁)

Sum of currents *leaving* V_col1 = 0:

$$
\frac{V_2 - 1}{2\text{ k}\Omega} + \frac{V_2 - V_1}{1\text{ k}\Omega} = 0
$$

Multiply through by 2 kΩ:

$$
(V_2 - 1) + 2(V_2 - V_1) = 0
$$

$$
\boxed{-2 V_1 + 3 V_2 = 1} \quad \text{...(2)}
$$

### Solving the system

From (1): $V_2 = 1.5\, V_1$

Substitute into (2):

$$
-2 V_1 + 3(1.5 V_1) = 1
$$

$$
-2 V_1 + 4.5 V_1 = 1 \implies 2.5 V_1 = 1
$$

$$
\boxed{V_{row1} = 0.400 \text{ V}, \quad V_{col1} = 0.600 \text{ V}}
$$

### Sanity check (current conservation at each floating node)

**At V_row1 = 0.4 V:**
- Current in from R[1][1]: (V₂ − V₁)/1 kΩ = (0.6 − 0.4)/1 kΩ = **+0.200 mA** (entering)
- Current out through R[1][0]: V₁/2 kΩ = 0.4/2 kΩ = **+0.200 mA** (leaving)
- Net = 0 ✓

**At V_col1 = 0.6 V:**
- Current in from R[0][1]: (1 − V₂)/2 kΩ = 0.4/2 kΩ = **+0.200 mA** (entering)
- Current out through R[1][1]: (V₂ − V₁)/1 kΩ = 0.2/1 kΩ = **+0.200 mA** (leaving)
- Net = 0 ✓

Both floating nodes balance, confirming the solution.

---

## (c) Actual I_col0 with Sneak Path Itemized

The sense node at col 0 (held at 0 V) collects current from **both** rows that connect to it:

| Path | Source node | Resistor | Current into col 0 |
|------|-------------|----------|--------------------|
| Direct (intended) | V_row0 = 1.000 V | R[0][0] = 1 kΩ | (1.000 − 0)/1 kΩ = **1.000 mA** |
| Sneak (parasitic) | V_row1 = 0.400 V | R[1][0] = 2 kΩ | (0.400 − 0)/2 kΩ = **0.200 mA** |
| **Total sensed** | | | **I_col0 = 1.200 mA** |

$$
\boxed{I_{col0}^{actual} = 1.000 \text{ mA (intended)} + 0.200 \text{ mA (sneak)} = 1.200 \text{ mA}}
$$

### Sneak path origin

Even though row 1 is not driven, current flows through the parasitic loop:

$$
V_{row0} \xrightarrow{R[0][1]=2\text{k}\Omega} V_{col1} \xrightarrow{R[1][1]=1\text{k}\Omega} V_{row1} \xrightarrow{R[1][0]=2\text{k}\Omega} V_{col0}
$$

The 1 V driver pushes 0.200 mA through this back-door path (R[0][1] + R[1][1] + R[1][0] in series = 5 kΩ, but loaded by the col-0 ground), raising V_row1 to 0.4 V and dumping that 0.200 mA into the sense node.

**Relative error:** 0.200 mA / 1.000 mA = **+20%** corruption of the intended MVM partial product, even with only one driven row in a 2×2 array.

---

## (d) Why Sneak Paths Corrupt MVM and Implications for Large Arrays

The sneak path adds 0.200 mA of current to col 0 that was never part of the intended dot product W[:,0] · x — the readout circuit cannot distinguish the legitimate (V_row0 / R[0][0]) contribution from the parasitic current routed through unselected cells via the floating row-1 node, so the sensed value reports a weight-input product that includes contributions from cells that should have been silent. In large N×N arrays, every unselected row provides an additional sneak loop in parallel, and the cumulative leakage scales roughly with N and with the on/off resistance ratio of the cells, causing the sensed column current to deviate from the true MVM by an error term that grows quickly with array size. This is why practical ReRAM/memristor crossbars require selector devices (1T1R, 1S1R), one-hot row activation, or grounding of all unselected lines — without these, MVM accuracy collapses past roughly 32×32 and the array becomes unusable for analog inference.


