# Milestone 4 — Ray-Object Intersection Accelerator

**Author:** Rajeshwar Vemula  
**Course:** ECE 510 HW4AI Spring 2026  
**Date:** June 7, 2026


## File Catalog

| Relative Path | Description | Checklist / Report Section |
|---|---|---|
| `README.md` | This file — catalogs all M4 deliverables | §1 README files |
| `rtl/top.sv` | Integrated top module: instantiates interface_top + compute_core | §2 Source code |
| `rtl/compute_core.sv` | Pipelined ray-sphere intersection pipeline (M4: STAGE_MUL added) | §2 Source code |
| `rtl/interface.sv` | AXI4-Lite register file + AXI4-Stream control (module: interface_top) | §2 Source code |
| `tb/tb_top.sv` | End-to-end testbench: 22 tests across 3 spheres from scene_city.json | §2 Source code |
| `sim/final_run.log` | VCS simulation transcript: 22/22 PASS with M4 pipelined design | §2 Source code |
| `sim/final_waveform.png` | Annotated timing diagram: AXI write → compute → AXI result | §2 Source code |
| `synth/config.json` | OpenLane 2 config: sky130_fd_sc_hd, 25 ns clock, 850×850 µm die | §3 Synthesis results |
| `synth/synth_top.sv` | Synthesis source (copy of compute_core.sv for OpenLane reproducibility) | §3 Synthesis results |
| `synth/openlane_run.log` | Full OpenLane flow.log: 78 stages, 0 DRC, 0 LVS | §3 Synthesis results |
| `synth/timing_report.txt` | Post-PNR STA: +2.03 ns worst slack at slow corner (all corners pass) | §3 Synthesis results |
| `synth/area_report.txt` | Yosys cell stats: 41,367 cells, 257,104 µm², 479 FFs | §3 Synthesis results |
| `synth/power_report.txt` | Power estimate: 39.6 mW at 40 MHz (nom_tt corner) | §3 Synthesis results |
| `bench/benchmark.md` | Throughput (3.3×), energy (1,257×), Amdahl analysis | §4 Benchmark |
| `bench/benchmark_data.csv` | Raw numbers: all metrics traceable to source | §4 Benchmark |
| `bench/roofline_final.png` | Measured roofline: SW baseline + M4 HW accelerator point | §4 Benchmark |
| `report/design_justification.pdf` | 9-section design report (~3,300 words) | §5 Report |
| `report/figures/roofline_final.png` | Figure 1: Roofline analysis plot | §5 Report |
| `report/figures/system_diagram.png` | Figure 2: System architecture block diagram | §5 Report |

## Changes from M3

| Component | M3 | M4 | Reason |
|---|---|---|---|
| compute_core.sv | STAGE_DISC: two 32×32 muls in 1 cycle | Split into STAGE_MUL + STAGE_DISC | Fix critical path |
| Latency | 23 cycles | 24 cycles | Extra pipeline stage |
| Clock target | 20 ns (50 MHz) | 25 ns (40 MHz) | 32×32 multiply exceeds 20 ns at slow corner |
| Setup WNS (slow) | -2.314 ns (FAIL) | +2.032 ns (PASS) | Pipeline + clock retarget |
| interface.sv | Unchanged | Unchanged | — |
| top.sv | Unchanged | Unchanged | — |

## Simulation Reproduction

```bash
cd project/m4
vcs -full64 -sverilog -timescale=1ns/1ns rtl/compute_core.sv rtl/interface.sv rtl/top.sv tb/tb_top.sv -o sim_m4
./sim_m4
```

**Simulator:** Synopsys VCS X-2025.06-SP1_Full64  
**Language:** IEEE 1800 SystemVerilog  
**Dependencies:** None. All reference values hardcoded in testbench.

## Synthesis Reproduction

```bash
cd project/m4/synth
sudo docker run --rm -v $(pwd):/work -w /work ghcr.io/efabless/openlane2:2.3.1 openlane /work/config.json
```

**OpenLane:** 2.3.1 (Docker: ghcr.io/efabless/openlane2:2.3.1)  
**PDK:** sky130_fd_sc_hd  
**Clock:** 25 ns (40 MHz) — closes timing at all 9 PVT corners
