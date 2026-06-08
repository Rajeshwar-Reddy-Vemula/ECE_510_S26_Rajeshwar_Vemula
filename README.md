# ECE 510 - Rajeshwar Reddy Vemula
Rajeshwar Reddy Vemula's codefest repository for  "Hardware for Artificial Intelligence and Machine Learning" (HW4AI) ECE 410/510 Spring 2026 at Portland State University

Ray-Object Intersection Accelerator

**Author:** Rajeshwar Reddy Vemula  
**Course:** ECE 510 HW4AI Spring 2026  
**Date:** June 7, 2026

This repository contains the complete design, verification, synthesis, and benchmarking package for a fixed-function ray-sphere intersection accelerator targeting the sky130_fd_sc_hd standard cell library. The accelerator implements the quadratic ray-sphere intersection formula in Q8.8 fixed-point arithmetic with an AXI4-Lite/Stream interface, synthesized at 40 MHz with clean timing closure at all PVT corners. It delivers 3.3× throughput improvement and 1,257× energy reduction compared to the Python software baseline, targeting embedded ADAS (LiDAR simulation) applications. The Milestone 4 submission, which is the final deliverable package, is located at [project/m4/README.md](project/m4/README.md). The design justification report covering all nine required sections (problem, roofline, precision, dataflow, interface, verification, synthesis, benchmarks, and lessons learned) is at [project/m4/report/design_justification.pdf](project/m4/report/design_justification.pdf).

## Repository Structure

```
project/
├── heilmeier.md              Heilmeier catechism
├── scope_assessment.md       Post-synthesis scope adjustment
├── m1/                       Software profiling, roofline, interface selection
├── m2/                       RTL development, unit testbenches, precision analysis
├── m3/                       Integration, co-simulation, first synthesis
└── m4/                       Final submission (start here)
    ├── README.md             File catalog with checklist references
    ├── rtl/                  Final RTL: top.sv, compute_core.sv, interface.sv
    ├── tb/                   Final testbench: tb_top.sv (22 tests, 3 spheres)
    ├── sim/                  Simulation log (22/22 PASS) and waveform
    ├── synth/                OpenLane 2 reports: timing, area, power
    ├── bench/                Benchmark: 3.3× speedup, roofline plot, raw data
    └── report/               Design justification PDF (9 sections, ~3,300 words)
codefest/                     Weekly codefest submissions (cf01–cf07)
```
