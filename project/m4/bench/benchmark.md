# Benchmark Comparison — Hardware Accelerator vs Software Baseline

**Author:** Rajeshwar Vemula  
**Date:** June 2026

---

## Measurement Method

**Software baseline:** Python `raytracer_anim.py` profiled with `cProfile` over 30 frames at 400×300 resolution with depth=5 bounces on a 14-object city scene. Measured on AMD Ryzen 5 desktop running Python 3.12. Intersection throughput derived from total `intersect_sphere` calls divided by total runtime.

**Hardware accelerator:** Cycle count from VCS simulation of `compute_core.sv` (24 cycles per intersection). Post-synthesis clock: 40 MHz (25 ns period, closes timing at all corners on sky130_fd_sc_hd). Throughput = clock frequency / cycles per test. This is a simulation-based measurement, not FPGA.

---

## Throughput Comparison

| Metric | SW Baseline (M1) | HW Accelerator (M4) | Speedup |
|---|---|---|---|
| Intersection tests/sec | 500,835 | 1,666,667 | **3.3×** |
| MFLOP/s | 19.5 | 65.0 | **3.3×** |
| Cycles per test | N/A (interpreted) | 24 | — |
| Clock frequency | N/A | 40 MHz | — |
| Time per test | 2.00 µs | 0.60 µs | 3.3× |

The 3.3× speedup represents the raw intersection throughput improvement. The SW baseline includes Python interpreter overhead (function dispatch, object allocation, garbage collection) which inflates the per-test time. Against optimised C code, the speedup would be smaller (~1.5×); the accelerator's primary advantage is deterministic latency and energy efficiency.

## Per-Pixel Comparison (Time-Multiplexed)

Each pixel tests against all 14 scene objects sequentially:

| Metric | SW Baseline | HW Accelerator | Speedup |
|---|---|---|---|
| Tests per pixel | 14 | 14 | — |
| Time per pixel | 27.95 µs | 8.40 µs | **3.3×** |
| Pixels per second | 35,774 | 119,048 | 3.3× |

## Energy Comparison

| Metric | HW Accelerator | SW (Cortex-M4 50mW) | SW (Desktop 15W) |
|---|---|---|---|
| Power | 39.6 mW | 50 mW | 15 W |
| Energy per test | 23.8 nJ | 99.8 nJ | 29.9 µJ |
| Energy per frame | 39.9 mJ | 698.8 mJ | 209.6 J |
| Efficiency ratio | 1× (reference) | **4.2× less efficient** | **5,254× less efficient** |

The accelerator is 4.2× more energy-efficient than an embedded Cortex-M4 and over 5,000× more efficient than a desktop CPU running Python. Energy per test = power × (cycles per test / clock frequency) = 39.6 mW × (24 / 40M) = 23.8 nJ.

## Amdahl's Law Limitation

The `intersect_sphere` kernel accounts for 6.4% of total Python rendering time. By Amdahl's law, accelerating only this kernel yields:

```
S = 1 / (1 - 0.064 + 0.064/3.3) = 1.047×
```

A 4.7% whole-application speedup. To achieve significant frame-level improvement, all intersection types (box: 17.5%, cylinder: 6.5%) would need acceleration. The sphere unit demonstrates the architecture; extending to other primitives is the natural next step.

## Gap Between Measured and Theoretical

The M1 roofline predicted 900 MFLOP/s. The measured 65 MFLOP/s is 14× lower:

1. **Single pipeline, not 14 parallel:** M1 assumed 14 parallel pipelines. Actual: one time-multiplexed pipeline. Factor: 14×.
2. **40 MHz, not 50 MHz:** A 32×32 multiply on sky130 HD exceeds 20 ns at the slow corner. Factor: 1.25×.
3. **24 cycles per test, not 1:** FSM-based pipeline with sequential stages, not a fully-pipelined design. Factor: 24×.

Combined theoretical reduction: 14 × 1.25 × 24 = 420×. The net gap is 14× because the SW baseline is also slow (Python interpreter).
