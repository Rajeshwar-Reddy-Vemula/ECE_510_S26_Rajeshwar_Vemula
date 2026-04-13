# HW/SW Partition Rationale
## Ray-Object Intersection Accelerator — ECE 510 HW4AI Spring 2026

---

## (a) Which kernels to accelerate and why the roofline supports it

The five intersection kernels — intersect_box, intersect_sphere,
intersect_cylinder, intersect_disk, and intersect_plane — together
account for 38.2% of total runtime (264s + 97s + 97s + 44s + 20s =
522s out of 1506s over 30 frames). The normalize function adds another
4.9% (74s). These six functions share a common arithmetic structure:
dot products followed by a square root or division. They are called
7,039,879 times per frame with identical structure on every call.

The roofline analysis shows these kernels have a software arithmetic
intensity of 0.38–0.81 FLOPs/byte, all below the ridge point of
~4.5 FLOPs/byte for a modern laptop CPU. They are memory-bound in
software not because the computation is data-heavy, but because Python
reloads all object parameters from DRAM on every call and spends ~6 µs
of dispatch overhead per call vs ~0.05 µs of actual arithmetic.

In hardware, object parameters are stored in on-chip registers and
reused across all rays. Only the ray direction (12 bytes) is streamed
per test. This raises the arithmetic intensity to 1.63–1.88 FLOPs/byte,
above the chiplet ridge point of 1.125 FLOPs/byte. The hardware design
is therefore compute-bound, and adding more MAC units directly
increases throughput — a clean scaling argument.

## (b) What stays in software

Scene loading from JSON, camera orbit calculation, reflection vector
computation, Phong shading evaluation, shadow ray dispatch logic,
image assembly, and PNG output all remain on the host CPU. These
operations are called at most once per pixel per bounce (not once per
ray-object test), run in Python with acceptable overhead, and involve
conditional branching and data-dependent control flow that is
inefficient to implement in fixed-function hardware.

## (c) Interface bandwidth requirement

Target throughput: 50 million intersection tests per second.
Data per test: 12 bytes in (ray direction D) + 4 bytes out (distance t).

```
Required bandwidth = 50M × 16 bytes = 800 MB/s
```

AXI4-Stream at 64-bit width and 100 MHz delivers exactly 800 MB/s.
With 85% bus utilisation (handshake overhead), effective throughput
is 56.7M tests/sec, which exceeds the 50M target. If parameters were
NOT held in registers and were streamed per test (28 bytes), required
bandwidth would rise to 1,400 MB/s — exceeding the interface — making
the register file the critical design decision that avoids this bottleneck.

## (d) Bound classification and how hardware changes it

On current hardware (laptop CPU, Python): **memory-bound**, AI = 0.61
FLOPs/byte. The bottleneck is Python dispatch overhead, not DRAM
bandwidth — each call wastes 6 µs on function call mechanics vs
0.05 µs of arithmetic.

On the chiplet (sky130 HD, 50 MHz): **compute-bound**, AI = 1.63–1.88
FLOPs/byte, above the ridge point of 1.125 FLOPs/byte. The hardware
eliminates dispatch overhead completely. Throughput is now limited by
the speed of the dot-product and square root pipeline, not by memory.
This is the correct operating regime for a fixed-function accelerator —
adding parallel pipelines directly multiplies throughput.
