# CMAN — DRAM Traffic Analysis: Naive vs. Tiled Matrix Multiply

## Setup

- N = 32 (matrix dimension)
- T = 8 (tile size)
- FP32 = 4 bytes per element
- DRAM Bandwidth = 320 GB/s
- Compute = 10 TFLOPS

---

## 1. Naive Triple Loop (ijk order)

```
for i in 0..N:
  for j in 0..N:
    for k in 0..N:
      C[i][j] += A[i][k] * B[k][j]
```

For one output element C[i][j], the inner k-loop reads:

- A[i][k] for k = 0 to N−1 → **N reads from A**
- B[k][j] for k = 0 to N−1 → **N reads from B**

Each element B[k][j] depends on k and j but not i. As i varies over N rows, B[k][j] is accessed once per i value:

**Accesses per element of B = N = 32**

Total accesses across all N² output elements:

- A accesses = N² × N = N³ = 32³ = 32,768
- B accesses = N² × N = N³ = 32³ = 32,768
- **Total accesses = 2N³ = 65,536**

Total DRAM traffic (no reuse, each access = 4 bytes, plus one write of N² elements for C):

```
T_naive = (2N³ + N²) × 4 = (65,536 + 1,024) × 4 = 266,240 bytes ≈ 260 KB
```

---

## 2. Tiled Loop (tile size T = 8)

### Traditional tiling (T-times reuse per tile load)

```
for i0 in 0..N/T:       # 4 tile rows
  for j0 in 0..N/T:     # 4 tile cols
    for k0 in 0..N/T:   # 4 accumulation steps
      load T×T tile of A(i0, k0) into shared memory
      load T×T tile of B(k0, j0) into shared memory
      tile multiply-accumulate
```

Total (i0, j0, k0) iterations = (N/T)³ = 4³ = 64. Each iteration loads two T×T tiles with T² = 64 elements.

Element A[i][k] sits in tile (i0, k0), loaded once per j0 → N/T = 4 times.
Element B[k][j] sits in tile (k0, j0), loaded once per i0 → N/T = 4 times.

Each element is loaded **N/T = 4 times** from DRAM, plus one write of C:

```
T_tiled_traditional = (2N³/T + N²) × 4 = (8,192 + 1,024) × 4 = 36,864 bytes ≈ 36 KB
```

### Ideal shared memory reuse (each element loaded once)

With sufficient on-chip memory, each element of A, B, and C is loaded/stored exactly once:

```
T_tiled_reused = 3N² × 4 = 3 × 1,024 × 4 = 12,288 bytes = 12 KB
```

---

## 3. Traffic Ratio

### Naive vs. Traditional Tiled 

```
T_naive / T_tiled_traditional = (2N³ + N²) / (2N³/T + N²) ≈ 2N³ / (2N³/T) = T = 8
```

The traditional tiling reduces traffic by a factor of **T = 8**. Each element is reused T times within a tile, reducing per-element DRAM loads from N to N/T.

### Naive vs. Ideal Reuse 

```
T_naive / T_tiled_reused = (2N³ + N²) / (3N²) ≈ 2N³ / 3N² ≈ 2N/3
```

For large N this simplifies to:

```
≈ N (for the dominant read traffic: 2N³ / 2N² = N = 32)
```

**Explanation:** In the naive loop each element is loaded from DRAM N times (once per iteration of the non-participating index), while shared memory tiling loads each element exactly once from DRAM and reuses it on-chip, eliminating all redundant loads and giving a traffic ratio of N.

---

## 4. Arithmetic Intensity & Execution Time

### System Ridge Point
To determine if we are limited by math or memory, we calculate the **Ridge Point** ($I_{rp}$):

$$I_{rp} = \frac{\text{Peak Compute}}{\text{Peak Bandwidth}} = \frac{10 \times 10^{12} \text{ FLOPS}}{320 \times 10^9 \text{ B/s}} = 31.25 \text{ FLOPs/byte}$$



### Kernel Classification
**Total Work:** $2 \times N^3 = 65,536 \text{ FLOPs}$  
**Compute Time ($T_{comp}$):** $65,536 / 10 \text{ TFLOPS} = 6.55 \text{ ns}$

| Metric | Naive Triple Loop | Tiled (Traditional) | Tiled (Ideal Reuse) |
| :--- | :--- | :--- | :--- |
| **Total Bytes** | 266,240 | 36,864 | 12,288 |
| **Arithmetic Intensity** | **0.246 FLOPs/B** | **1.77 FLOPs/B** | **5.33 FLOPs/B** |
| **Memory Time ($T_{mem}$)** | 832.0 ns | 115.2 ns | 38.4 ns |
| **Classification** | **Memory-Bound** | **Memory-Bound** | **Memory-Bound** |

**Final Classification:**
All three kernels are **Memory-bound** because their Arithmetic Intensities ($0.246 \to 5.33$) are significantly lower than the system ridge point of **31.25**. Even with ideal reuse, the small matrix size ($N=32$) does not provide enough data reuse to saturate the 10 TFLOPS compute engine. Performance is strictly limited by how fast the 320 GB/s bus can feed the cores.
