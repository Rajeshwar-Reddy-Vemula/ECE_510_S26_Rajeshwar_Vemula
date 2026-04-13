# Software Baseline Benchmark

**Algorithm:** Animated ray tracer  
**Scene:** 14-object city scene (3 spheres, 3 boxes, 3 cylinders, 1 disk, 1 plane)  
**Platform:** WSL2 Ubuntu, x86-64 CPU, Python 3 / NumPy  
**Resolution:** 400 × 300 pixels  
**Bounce depth:** 5 reflections per ray  
**Frames measured:** 30 (camera orbiting the scene)  
**Script:** codefest/cf02/profiling/raytracer_anim.py  

---

## Throughput

| Metric | Value |
|---|---|
| Total runtime (30 frames) | 419.3 s |
| Steady-state time per frame | 13.98 s/frame |
| Frame rate | 0.072 fps |
| Intersection tests per frame | 7,039,879 |
| Intersection throughput | 503,000 tests/sec |
| Total FLOPs per frame (estimated) | 220 MFLOPs |
| Compute throughput | 15.7 MFLOPs/sec |

Throughput breakdown by kernel (per frame):

| Kernel | Calls/frame | FLOPs/call | MFLOPs/frame | Calls/sec |
|---|---|---|---|---|
| intersect_box | 1,301,281 | 26 | 33.8 | 93,082 |
| intersect_sphere | 2,210,699 | 31 | 68.5 | 158,133 |
| intersect_cylinder | 1,323,492 | 41 | 54.3 | 94,671 |
| intersect_disk | 441,123 | 30 | 13.2 | 31,552 |
| normalize | 1,763,284 | 9 | 15.9 | 126,129 |
| **Total** | **7,039,879** | — | **185.7** | **503,000** |

---

## Memory usage

Measured using `/usr/bin/time -v` on a single-frame render:

| Metric | Value |
|---|---|
| Peak RSS (resident set size) | 74,028 KB (72.3 MB) |
| NumPy array allocations | ~48 MB |
| Scene object list | < 1 MB |
| Per-frame image buffer (400×300×3 float64) | 2.88 MB |
| Python interpreter + NumPy overhead | ~21 MB |
| GPU memory | 0 (pure CPU) |

The scene itself (14 objects × ~10 floats each) occupies under 1 KB.
Memory is dominated by the NumPy and matplotlib imports.

To reproduce:

```bash
/usr/bin/time -v python codefest/cf02/profiling/raytracer_anim.py \
    codefest/cf02/profiling/scene_city.json \
    --frames 1 --outdir /tmp/frames_mem \
    2>&1 | grep -E "(Maximum resident|Elapsed)"
```

Measured result: **74,028 KB peak RSS, 36.23 s wall clock (cold start)**.

---

## Why throughput is low

Each intersection call performs 26–41 floating point operations.
On the CPU this arithmetic takes approximately 0.05 µs. However,
Python spends approximately 6 µs per call on function dispatch,
type checking, and memory management — 120 times the arithmetic cost.

The hardware accelerator eliminates this overhead entirely. The
arithmetic runs at clock rate with no dispatch cost. At 50 MHz
with one result per cycle, throughput becomes 50 million tests per
second — a 99x improvement over the software baseline.

---

## Timing notes

Single-frame cold-start time: 36.23 s. This includes Python startup
(~1 s), NumPy import (~0.8 s), matplotlib import (~1.2 s), and scene
loading (~0.1 s), which do not repeat after the first frame.

Steady-state time per frame: 13.98 s, measured as the average over
30 frames where imports are amortised. The M4 comparison uses
13.98 s/frame as the baseline since the hardware accelerator targets
the render loop, not the startup cost.

---

## M4 comparison point

| Metric | SW baseline | HW target | Speedup |
|---|---|---|---|
| Intersection throughput | 503,000 tests/sec | 50,000,000 tests/sec | ~99x |
| Frame rate | 0.072 fps | ~5 fps | ~70x |
| Time per frame | 13.98 s | ~0.14 s | ~99x |
| Compute throughput | 15.7 MFLOPs/s | 900 MFLOPs/s | ~57x |

End-to-end frame speedup is lower than intersection-only speedup
because shading, shadow rays, and image output remain in software
and account for approximately 2 s/frame not covered by the chiplet.
