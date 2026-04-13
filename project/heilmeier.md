# Heilmeier Catechism — ECE 510 HW4AI Spring 2026
**Student:** Rajeshwar Vemula  
**Project:** Ray-Object Intersection Accelerator Chiplet  
**Date:** April 12, 2026  

---

## Q1 — What are you trying to do?

Design and synthesize a fixed-function co-processor chiplet that
accelerates the geometric ray-object intersection kernel used in
real-time ray tracing for embedded applications. The target kernel
covers five primitive types — sphere, box, cylinder, disk, and plane —
which together describe the dominant compute workload in applications
such as LiDAR sensor simulation for ADAS validation, robotic scene
understanding, digital twin rendering, and occupancy grid computation
for autonomous navigation.

The chiplet receives a stream of ray direction vectors and scene
object parameters over an AXI4-Lite / AXI4-Stream interface, performs
the intersection test in a pipelined fixed-function arithmetic unit,
and returns the nearest hit distance. The goal is to reduce the
per-intersection latency from ~6 µs on a general-purpose CPU running
Python to ~20 ns on the chiplet — a 300× improvement — while
consuming under 2 mW of dynamic power on the sky130 HD process at
50 MHz.

---

## Q2 — What is done today and what are the limits?

**Software baseline (this work):** A Python/NumPy animated ray tracer
renders a 14-object city scene (spheres, boxes, cylinders, disks,
checkerboard plane) at 400×300 pixels with 5 reflection bounces.
Profiling over 30 frames shows:

| Kernel            | Calls (30f)  | Total time | % runtime |
|-------------------|-------------|------------|-----------|
| intersect_box     | 39,038,423  | 263.9 s    | 17.5%     |
| intersect_sphere  | 66,320,973  |  96.9 s    |  6.4%     |
| intersect_cylinder| 39,704,759  |  97.2 s    |  6.5%     |
| normalize         | 52,898,527  |  73.9 s    |  4.9%     |
| intersect_disk    | 13,233,675  |  43.9 s    |  2.9%     |

Frame rate: **0.072 fps** (13.98 s/frame). All five kernels are
dominated by dot products, square roots, and scalar divisions —
the Python per-call dispatch overhead of ~6 µs far exceeds the
actual arithmetic time of ~0.05 µs.

**GPU ray tracing (NVIDIA RTX):** Modern GPUs solve this problem with
dedicated RT Cores introduced in the Turing architecture (RTX 2000
series, 2018). However, the GPU approach has fundamental limitations
for embedded and edge applications:

- An RTX 4090 has 128 RT Cores but also 16,384 CUDA cores, 512 Tensor
  Cores, 24 GB of GDDR6X memory, and draws 450 W. The RT Cores cannot
  be purchased or deployed separately from the rest of the GPU.
- The GPU is a general-purpose parallel processor. Its CUDA cores
  handle shading, denoising (via Tensor Cores), and everything else.
  The RT Cores handle only BVH traversal and triangle intersection.
  This makes the GPU efficient at rendering full scenes with millions
  of triangles, but massively over-provisioned for applications that
  need to test rays against a small number of analytic primitives
  (dozens of spheres and boxes, not millions of triangles).
- Connecting a GPU to an embedded ECU requires PCIe Gen4/5, a full
  driver stack, and a host CPU capable of managing the GPU runtime.
  Automotive ECUs (Mobileye EyeQ6, NVIDIA Orin) have a total power
  budget of 20–45 W shared across all functions. A 450 W GPU is
  not deployable in this context.
- The RT Core implements BVH traversal — a general tree search with
  a hardware stack and pointer chasing. For fixed small scenes where
  all object parameters are known at configuration time, this
  generality is wasted. A fixed-function intersection pipeline with
  object parameters held in on-chip registers is simpler, smaller,
  and faster for this specific workload.

**Embedded CPUs:** ARM Cortex-M and Cortex-A processors used in ADAS
ECUs run ray-object intersection in software at 50k–200k tests/second.
At 10 Hz LiDAR frame rate with 128 beams × 10 bounces, this requires
1.28M intersection tests per second — 6–25× beyond what the embedded
CPU can sustain in real time.

---

## Q3 — What is new in your approach?

Instead of a general-purpose GPU with thousands of shader cores and
a handful of RT Cores, this design implements a narrow fixed-function
chiplet that does exactly one thing: evaluate ray-object intersection
for analytic geometric primitives.

**Key architectural differences from the GPU approach:**

1. **Query-stationary dataflow.** Object parameters (sphere center and
   radius, box bounds, cylinder axis and radius) are loaded once into
   on-chip registers at scene configuration time and held there for
   the entire frame. Only ray direction vectors are streamed in per
   test. This transforms the arithmetic intensity from 0.63 FLOPs/byte
   (memory-bound, like the software baseline) to ~1.9 FLOPs/byte
   (approaching compute-bound), because DRAM traffic is reduced to
   only the ray direction input rather than reloading all object
   parameters on every call.

2. **Pipelined dot-product + reciprocal square root unit.** The
   dominant arithmetic in all five intersection kernels is a sequence
   of dot products (3-element float vectors) followed by a square root
   or division. In hardware this is a 3-cycle multiply-accumulate tree
   feeding a Newton-Raphson reciprocal square root stage — a 10-stage
   pipeline producing one result per clock cycle after fill. This is
   fundamentally different from a MAC array (used for convolution and
   matrix multiply by classmates) because the computation graph is a
   tree with a nonlinear stage (sqrt, reciprocal) at the output.

3. **Fixed scene, small object count.** A GPU RT Core must handle
   dynamic scenes with millions of triangles and arbitrary BVH depth.
   This chiplet targets scenes with 10–50 analytic primitives, all
   parameters held in registers. There is no BVH, no pointer chasing,
   no stack. The hardware is a parallel bank of primitive testers —
   one pipeline per object type — with a min-reduction tree to find
   the nearest hit. For 14 objects, this is 14 parallel pipelines
   feeding a 4-level reduction tree: ~50 clock cycles total latency
   at 50 MHz = 1 µs per frame pixel vs 14 µs in software.

4. **Target platform and power.** The chiplet targets sky130 HD at
   50 MHz, estimated area ~640 standard cells, estimated dynamic power
   < 2 mW. This fits within the co-processor power budget of a
   Mobileye EyeQ-class automotive ECU, where a GPU is not an option.
   The same math — dot products, square roots, slab tests — appears in
   LiDAR simulation, radar cross-section computation, and V2X
   line-of-sight queries, all of which run on exactly this class of
   embedded hardware.

The novelty is not a new algorithm — ray tracing is decades old — but
a new implementation point: a minimal synthesizable chiplet that
delivers GPU-class intersection throughput at embedded-class power,
by exploiting the constraints (small fixed scene, analytic primitives,
known parameters) that general-purpose GPU hardware cannot assume.
