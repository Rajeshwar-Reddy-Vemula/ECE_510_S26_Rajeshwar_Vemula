# GEMM Analysis: Naive vs. Tiled (NVIDIA T4)

## Measured Data

| Metric | Naive | Tiled (T=8) |
|---|---|---|
| Kernel time | 6.801 ms | 5.482 ms |
| Performance | 315.74 GFLOP/s | 391.70 GFLOP/s |
| DRAM traffic (ncu) | 214.50 MB | 174.53 MB |
| Arithmetic Intensity | 10.01 FLOP/B | 12.30 FLOP/B |
| DRAM throughput (% peak) | 7.27% | 5.89% |
| SM throughput (% peak) | 62.47% | 55.21% |
| Roofline ceiling at measured AI | 3,203 GFLOP/s | 3,936 GFLOP/s |
| Utilization (achieved/ceiling) | 9.9% | 10.0% |

## (a) Why the naive kernel is memory-bound

The naive kernel achieves 315.74 GFLOP/s with a measured arithmetic intensity of 10.01 FLOP/byte, placing it well to the left of the T4 ridge point at 25.3 FLOP/byte on the roofline. At this AI, the memory bandwidth ceiling caps performance at 3,203 GFLOP/s — the kernel can never reach the 8,100 GFLOP/s compute peak regardless of SM efficiency. In a theoretical no-cache model, the naive kernel performs 2N³ = 2×1024³ element accesses from DRAM for both A and B, totaling 2N³ × 4 = 8,589,934,592 bytes (~8.59 GB). This gives a theoretical AI of just 2N³ / (2N³ × 4) = 0.25 FLOP/byte — extremely memory-bound. However, the T4 has a 6MB L2 cache that transparently intercepts many of these redundant accesses. The ncu profiling measured only 214.50 MB of actual DRAM traffic, meaning the L2 cache absorbed roughly 97.5% of the theoretical 8.59 GB, elevating the measured AI from 0.25 to 10.01. Despite this massive cache benefit, 214.50 MB is still 18x more than the theoretical minimum of 12 MB (reading each of the three matrices exactly once). The kernel remains memory-bound because the L2 cannot capture all reuse — elements of B accessed in column-strided patterns cause cache line evictions, and the 12 MB working set exceeds the 6 MB L2 capacity. The kernel achieves only 9.9% of its roofline ceiling, further limited by poor latency hiding with the 16×16 thread block configuration.

## (b) How tiling reduces DRAM traffic

Tiling loads T×T sub-blocks of A and B into on-chip shared memory before computing partial products. Within each tile, every loaded element is reused T=8 times — once for each row or column of the T×T output sub-block — before the next tile is fetched. This software-managed reuse explicitly reduces redundant DRAM fetches. In a no-cache theoretical model, the naive kernel accesses 2N³ elements from DRAM, while the tiled kernel accesses 2N³/T elements, giving a theoretical traffic reduction of T=8x. Our ncu profiling confirms that tiling does reduce traffic: DRAM dropped from 214.50 MB (naive) to 174.53 MB (tiled), a measured ratio of 1.23x. The arithmetic intensity correspondingly increased from 10.01 to 12.30 FLOP/byte. The tiled kernel achieves higher reuse than the naive kernel through two complementary mechanisms: the explicit shared memory reuse within each tile (software-managed, guaranteed T=8 reuses per element), plus the same L2 cache reuse that the naive kernel benefits from. This layered reuse — shared memory on top of L2 — is why the tiled kernel's measured AI of 12.30 exceeds the naive kernel's 10.01. The tiled kernel pushes more of the remaining L2-missed traffic into shared memory, squeezing additional reuse beyond what the hardware cache alone can provide. However, the improvement is modest (1.23x, not 8x) because the L2 cache was already providing most of the reuse for the naive kernel at this matrix size.

## (c) Did the tiled kernel achieve the expected improvement?

The tiled kernel achieved a 1.24x speedup (391.70 vs 315.74 GFLOP/s) and a 1.23x DRAM traffic reduction (174.53 vs 214.50 MB). Both numbers are consistent — the speedup closely tracks the actual traffic reduction — but fall well short of the theoretical T=8x improvement. The primary reason is that the T4's 6MB L2 cache already absorbs the vast majority of redundant accesses for the naive kernel, leaving little room for shared memory tiling to improve upon. The 12 MB working set (3 × 1024² × 4 bytes) partially fits in L2, so hardware caching already delivers much of the reuse that tiling provides in software. The remaining DRAM traffic in both kernels is dominated by compulsory misses and L2 evictions that neither shared memory nor L2 can eliminate at this working set size. Additionally, the T=8 tile size creates thread blocks of only 64 threads (8×8), far below the 256+ threads per block needed for good occupancy on the T4's 40 SMs. Low occupancy means too few active warps to hide memory latency through warp scheduling. Both kernels achieve roughly 10% of their respective roofline ceilings (3,203 and 3,936 GFLOP/s), indicating the remaining bottleneck is compute efficiency: insufficient instruction-level parallelism, potential shared memory bank conflicts on column accesses of sB, and too few active warps per SM. To see the full T=8x benefit of tiling, one would need larger matrices (e.g., 4096×4096 or beyond) where the working set far exceeds L2 capacity, forcing the naive kernel back toward its theoretical 0.25 FLOP/byte AI while the tiled kernel maintains its shared memory reuse advantage.
