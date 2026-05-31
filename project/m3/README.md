# Milestone 3 — Ray-Object Intersection Accelerator

**Author:** Rajeshwar Vemula  
**Course:** ECE 510 HW4AI Spring 2026  
**Date:** May 24, 2026

---

## File Catalog

| Path | Description |
|---|---|
| `project/m3/README.md` | This file — catalogs all M3 deliverables |
| `project/m3/rtl/top.sv` | Integrated top module instantiating interface_top and compute_core |
| `project/m3/rtl/interface_top.sv` | AXI4-Lite slave register file + AXI4-Stream control logic |
| `project/m3/rtl/compute_core.sv` | Ray-sphere intersection pipeline with embedded non-restoring sqrt |
| `project/m3/tb/tb_top.sv` | End-to-end co-simulation testbench — 22 tests across 3 spheres |
| `project/m3/sim/cosim_run.log` | VCS simulation transcript showing 22/22 PASS |
| `project/m3/sim/cosim_waveform.png` | Waveform showing AXI write, compute, and AXI result phases |
| `project/m3/synth/config.json` | OpenLane 2 configuration — sky130 HD, 20 ns clock, 850x850 die |
| `project/m3/synth/openlane_run.log` | Full OpenLane 2 stdout/stderr from synthesis run |
| `project/m3/synth/metrics.csv` | OpenLane 2 final metrics — timing, area, power, DRC, LVS |
| `project/m3/synth/timing_report.txt` | Setup/hold slack across all corners |
| `project/m3/synth/area_report.txt` | Cell count, area breakdown by type |
| `project/m3/synth/power_report.txt` | Power estimation from OpenLane 2 |
| `project/m3/synth/critical_path.md` | Critical path identification and analysis |
| `project/m3/synthesis_notes.md` | Narrative — what synthesized, what failed, scope adjustment |

---

## Simulator and Reproduction

**Simulator:** Synopsys VCS  
**Version:** X-2025.06-SP1_Full64  
**Language:** IEEE 1800 SystemVerilog

### Co-simulation (end-to-end testbench)

```bash
cd project/m3

vcs -full64 -sverilog -timescale=1ns/1ns rtl/compute_core.sv rtl/interface_top.sv rtl/top.sv tb/tb_top.sv -o sim_m3

./sim_m3 | tee sim/cosim_run.log
```

To generate waveform:

```bash
vcs -full64 -sverilog -timescale=1ns/1ns rtl/compute_core.sv rtl/interface_top.sv rtl/top.sv tb/tb_top.sv -o sim_m3 -debug_access+all

./sim_m3 +vcs+vcdpluson

dve -vpd vcdplus.vpd &
```

### OpenLane 2 synthesis

**OpenLane version:** 2.3.10 (pip) with Docker image ghcr.io/efabless/openlane2:2.3.1  
**PDK:** sky130_fd_sc_hd  
**Clock:** 20 ns (50 MHz)

```bash
cd codefest/cf07/hdl

sudo docker run --rm \
    -v $(pwd):/work \
    -w /work \
    ghcr.io/efabless/openlane2:2.3.1 \
    openlane /work/config.json
```

No external dependencies. No Python or C preprocessing required. All reference values are hardcoded in the testbench.

---

## Design Hierarchy

```
top (top.sv)
├── interface_top u_intf (interface_top.sv)
│   ├── AXI4-Lite slave — register file for ray origin + sphere params
│   ├── AXI4-Stream slave — ray direction input (64-bit: {unused, dz, dy, dx})
│   ├── AXI4-Stream master — hit distance output (64-bit: {zeros, t})
│   └── Stream control FSM — busy/done, output holding register
│
└── compute_core u_core (compute_core.sv)
    ├── Input latch registers
    ├── OS = O - S subtractors
    ├── Dot product units (a, b, c coefficients)
    ├── Discriminant calculator (b²-4ac)
    ├── Embedded non-restoring integer sqrt (16 iterations)
    └── t = (-b - sqrt) / 2a output stage
```

### Inter-module wiring (no glue logic)

| Signal | Direction | Width | Purpose |
|---|---|---|---|
| reg_ray_ox/oy/oz | intf → core | 16 each | Ray origin from AXI4-Lite registers |
| stream_ray_dx/dy/dz | intf → core | 16 each | Ray direction from AXI4-Stream |
| reg_sph_cx/cy/cz | intf → core | 16 each | Sphere center from AXI4-Lite registers |
| reg_sph_r | intf → core | 16 | Sphere radius from AXI4-Lite register |
| core_start | intf → core | 1 | Start pulse from stream handshake |
| core_hit_distance | core → intf | 16 | Hit distance result Q8.8 |
| core_hit_valid | core → intf | 1 | 1 if ray hits sphere |
| core_done | core → intf | 1 | Done pulse after computation |

---

## Test Strategy

22 hand-picked test vectors exercising the dominant kernel (`intersect_sphere`) from M1 profiling:

| Tests | Sphere | Type | What it proves |
|---|---|---|---|
| 1-4 | Blue (0,0,1.5) r=0.45 | 4 hits | Direct, upper, right, grazing angles |
| 5-6 | Blue | 2 misses | Near-miss, opposite direction |
| 7-10 | Orange (-2.75,0.1,3.5) r=0.6 | 4 hits | Different sphere, longer distances |
| 11-12 | Orange | 2 misses | Near-miss, far-miss |
| 13-16 | Red (2.0,-0.2,4.0) r=0.35 | 4 hits | Third sphere, furthest distances |
| 17-18 | Red | 2 misses | Near-miss, far-miss |
| 19-22 | Blue (edge cases) | 1 hit + 3 misses | Behind camera, straight up, ahead, 45° |

All expected values independently computed by Python FP64 `intersect_sphere()` from `raytracer_anim.py`, then adjusted for Q8.8 quantization. Tolerance: ±3 LSB (0.012 scene units), below the 0.025 pixel rendering threshold.

Additionally verified with 999 randomised tests (333 per sphere) using embedded Q8.8 software model — 999/999 PASS (see earlier verification runs).

---

## Synthesis Results Summary

| Metric | Value |
|---|---|
| Target clock | 20 ns (50 MHz) |
| Setup slack (typical corner) | +8.67 ns (passes) |
| Setup slack (slow corner) | -2.31 ns (fails by 2.31 ns) |
| Hold slack | +0.11 ns (passes all corners) |
| Total cells | 41,118 |
| Sequential cells | 479 |
| Combinational cells | 27,542 |
| Cell area | 248,852 µm² |
| Die area | 722,500 µm² (850×850) |
| Utilization | 35.9% |
| Total power | 39.8 mW |
| DRC errors | 0 |
| LVS errors | 0 |

Design passes timing at typical and fast corners. Slow corner (ss, 100°C, 1.60V) fails setup by 2.31 ns — achievable clock is approximately 22.3 ns (44.8 MHz). See `critical_path.md` and `synthesis_notes.md` for analysis and M4 plan.

---

## Deviations from M1/M2

| Deviation | Rationale |
|---|---|
| Module name `interface_top` instead of `interface` | `interface` is a reserved keyword in IEEE 1800 SystemVerilog |
| Q8.8 fixed-point instead of FP32 | Halves memory traffic, eliminates FP hardware. Error within LiDAR tolerance. |
| Single sphere tester instead of 14 parallel | 41,118 cells for one tester — 14 parallel would exceed any reasonable die budget. Time-multiplexed mode provides 13× speedup. |
