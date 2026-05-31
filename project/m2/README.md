# ECE 510 HW4AI Spring 2026 — Milestone 2 README

**Author:** Rajeshwar Vemula  
**Project:** Ray-Object Intersection Accelerator

---

## 1. Simulation Environment & Execution

The verification environment is designed for out-of-the-box execution from a clean repository clone.

* **Primary Simulator:** Synopsys VCS
* **Version:** X-2025.06-SP1_Full64
* **Language Standard:** IEEE 1800 SystemVerilog

To reproduce the simulations, execute the following commands in your terminal from the project root directory:

**A. Compute Core Testbench**
Validates the isolated math pipeline and geometry calculations.
```bash
vcs -full64 -sverilog -timescale=1ns/1ns project/m2/rtl/compute_core.sv project/m2/tb/tb_compute_core.sv -o sim_core
./sim_core
```

**B. Interface Wrapper Testbench**
Validates the AXI4-Lite control plane and AXI4-Stream data plane handshakes.
```bash
vcs -full64 -sverilog -timescale=1ns/1ns project/m2/rtl/compute_core.sv project/m2/rtl/interface.sv project/m2/tb/tb_interface.sv -o sim_interface
./sim_interface
```

---

## 2. File Catalog

| Path | Description |
|---|---|
| `project/m2/README.md` | This file |
| `project/m2/rtl/compute_core.sv` | Ray-sphere intersection pipeline with embedded non-restoring sqrt |
| `project/m2/rtl/interface.sv` | AXI4-Lite slave + AXI4-Stream control + compute_core instantiation |
| `project/m2/tb/tb_compute_core.sv` | 4-test compute core testbench (8 PASS, 0 FAIL) |
| `project/m2/tb/tb_interface.sv` | 4-test interface testbench (13 PASS, 0 FAIL) |
| `project/m2/sim/compute_core_run.log` | VCS transcript — compute core 8/8 PASS |
| `project/m2/sim/interface_run.log` | VCS transcript — interface 13/13 PASS |
| `project/m2/precision.md` | Q8.8 vs FP64 error analysis |

---

## 3. Build Requirements & Reproducibility

* **Dependencies:** None.
* **Pre/Post-Processing:** There are no external Python or C dependencies required to run these simulations. All reference calculations (converting FP64 floating-point values to Q8.8 fixed-point hex values) were completed offline. The expected outputs are hardcoded directly into the SystemVerilog testbenches to guarantee zero-dependency reproducibility.

---

## 4. Design Overview

### Compute Core (`compute_core.sv`)

Ray-sphere intersection pipeline implementing the quadratic formula:
```
OS   = O - S
a    = dot(D, D)
b    = 2 * dot(D, OS)
c    = dot(OS, OS) - R²
disc = b² - 4ac
t    = (-b - sqrt(disc)) / 2a
```

* **Precision:** Q8.8 signed fixed-point (16-bit)
* **Intermediates:** Q16.16 (32-bit products), Q32.32 (64-bit discriminant)
* **Square root:** Non-restoring integer algorithm, 16 iterations, embedded directly in module
* **Latency:** 23 clock cycles at 50 MHz
* **FSM:** IDLE → STAGE_OS → STAGE_DOTS → STAGE_DISC → SQRT_INIT → SQRT_RUN → STAGE_T → DONE

### Interface (`interface.sv`, module name `interface_top`)

* **AXI4-Lite slave:** Register file for ray origin (0x04-0x0C) and sphere parameters (0x1C-0x28)
* **AXI4-Stream slave:** Ray direction input packed as {unused[63:48], dz, dy, dx}
* **AXI4-Stream master:** Hit result output as {zeros[63:16], hit_distance[15:0]}
* **Stream control:** `s_axis_tready = ~reg_busy`, start on valid+ready handshake
* **Output holding:** Result held until master accepts via `m_axis_tready`

---

## 5. Deviations from Milestone 1 Plan

**Deviation 1: Interface Module Naming Constraint**

* **Change:** The top-level interface module and file were renamed from `interface.sv` to `interface_top`.
* **Rationale:** `interface` is a strictly reserved keyword in IEEE 1800 SystemVerilog. Using it triggers fatal compiler errors in standard EDA tools (including VCS). The module was safely renamed to `interface_top`.

**Deviation 2: Precision Target and Arithmetic Hardware**

* **Change:** The numerical data format was changed from standard FP32 (32-bit floating-point) to a custom Q8.8 fixed-point format. The underlying hardware uses pure integer arithmetic instead of floating-point blocks.
* **Rationale:** M1 profiling proved the ray-sphere intersection kernel is heavily memory-bound. Shrinking the data width from FP32 to 16-bit Q8.8 cuts memory traffic exactly in half, doubling the effective AXI-Stream data transfer rate. Furthermore, shifting from complex FP arithmetic to pure integer arithmetic eliminates the massive logic overhead required for exponent alignment. This saves significant silicon area while keeping the final geometric error (~0.015 meters) completely buried within the acceptable 2-3 cm physical noise floor of standard LiDAR sensors. (Detailed analysis is available in `precision.md`).
