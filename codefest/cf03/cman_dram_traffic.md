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

Total DRAM traffic (no reuse, each access = 4 bytes):

```
T_naive = 2N³ × 4 = 65,536 × 4 = 262,144 bytes = 256 KB
```

---

## 2. Tiled Loop (tile size T = 8, shared memory reuse)

With shared memory tiling, each element of A and B is loaded from DRAM **exactly once** into shared memory and reused on-chip for all computations that need it. The total data loaded is simply the size of each matrix:

- A loads = N² = 32² = 1,024 elements
- B loads = N² = 32² = 1,024 elements
- **Total loads = 2N² = 2,048 elements**

```
T_tiled = 2N² × 4 = 2,048 × 4 = 8,192 bytes = 8 KB
```

---

## 3. Traffic Ratio

```
T_naive / T_tiled = (2N³ × 4) / (2N² × 4) = N³ / N² = N = 32
```

**One-sentence explanation:** In the naive loop each element is loaded from DRAM N times (once per iteration of the non-participating index), while shared memory tiling loads each element exactly once from DRAM and reuses it on-chip, eliminating all redundant loads and giving a traffic ratio of N.

---

## 4. Execution Time and Bottleneck

### Total FLOPs

```
FLOPs = 2N³ = 2 × 32³ = 65,536
```

### Compute time (same for both — identical FLOPs)

```
t_compute = 65,536 / (10 × 10¹²) = 6.55 × 10⁻⁹ s = 6.55 ns
```

### Naive memory time

```
t_mem_naive = 262,144 / (320 × 10⁹) = 8.192 × 10⁻⁷ s = 819.2 ns
```

### Tiled memory time

```
t_mem_tiled = 8,192 / (320 × 10⁹) = 2.56 × 10⁻⁸ s = 25.6 ns
```

### Execution time = max(compute, memory)

| Case  | Memory Time | Compute Time | Ratio (mem/compute) | Bottleneck               |
|-------|-------------|--------------|---------------------|--------------------------|
| Naive | 819.2 ns    | 6.55 ns      | 125×                | **Memory-bound**         |
| Tiled | 25.6 ns     | 6.55 ns      | 3.9×                | **Memory-bound (near ridge)** |

The naive kernel is overwhelmingly memory-bound at 125× the compute time. The tiled kernel is still technically memory-bound but only 3.9× from the ridge — tiling moved it dramatically closer to compute-bound territory.

---

---

## Appendix: Traditional Tiled Analysis (T-times reuse per tile load)

The analysis above uses the professor's model where shared memory allows each element to be loaded from DRAM exactly once (total traffic = 2N²). An alternative standard model (used in Hwu/Kirk's textbook and most GPU programming references) counts how many times each tile must be reloaded across the full computation.

### Tiled loop structure

```
for i0 in 0..N/T:       # 4 tile rows
  for j0 in 0..N/T:     # 4 tile cols
    for k0 in 0..N/T:   # 4 accumulation steps
      load T×T tile of A(i0, k0) into shared memory
      load T×T tile of B(k0, j0) into shared memory
      tile multiply-accumulate
```

### Counting tile loads

Total (i0, j0, k0) iterations = (N/T)³ = (32/8)³ = 4³ = 64

Each iteration loads two T×T tiles (one from A, one from B), each with T² = 64 elements:

- A tile loads = 64 × 64 = 4,096 elements
- B tile loads = 64 × 64 = 4,096 elements
- **Total element loads = 8,192**

### Per-element reload count

Element A[i][k] sits in tile (i0, k0). That tile is loaded once per j0 value → N/T = 4 times.
Element B[k][j] sits in tile (k0, j0). That tile is loaded once per i0 value → N/T = 4 times.

Each element is loaded **N/T = 4 times** from DRAM, not once.

### Traffic

```
T_tiled_traditional = 2 × N² × (N/T) × 4 = 2 × 1024 × 4 × 4 = 32,768 bytes = 32 KB
```

Or equivalently:

```
T_tiled_traditional = (N/T)³ × 2T² × 4 = 64 × 128 × 4 = 32,768 bytes = 32 KB
```

### Ratio (traditional model)

```
T_naive / T_tiled_traditional = (2N³) / (2N³/T) = T = 8
```

### Execution time (traditional model)

```
t_mem_tiled_traditional = 32,768 / (320 × 10⁹) = 102.4 ns
```

| Case                    | Memory Time | Compute Time | Ratio (mem/compute) | Bottleneck                    |
|-------------------------|-------------|--------------|---------------------|-------------------------------|
| Naive                   | 819.2 ns    | 6.55 ns      | 125×                | **Memory-bound**              |
| Tiled (professor model) | 25.6 ns     | 6.55 ns      | 3.9×                | **Memory-bound (near ridge)** |
| Tiled (traditional)     | 102.4 ns    | 6.55 ns      | 15.6×               | **Memory-bound**              |

### Why the two models differ

| Model                | Assumes                                      | Per-element loads | Total traffic | Ratio |
|----------------------|----------------------------------------------|-------------------|---------------|-------|
| Professor's model    | Each element loaded once (full matrix cached) | 1                 | 2N² × 4       | N = 32 |
| Traditional model    | Each tile reloaded per outer loop iteration   | N/T               | 2N³/T × 4     | T = 8  |

The professor's model represents the **idealized best case** where on-chip memory (shared memory + caches) is large enough to hold all needed data so each element is fetched from DRAM exactly once. The traditional model represents the **realistic tiling case** where only T×T tiles fit in shared memory at a time, requiring each element to be reloaded N/T times as different output tiles need it.

For N = 32 with T = 8, the matrix is small enough (3 × 32² × 4 = 12 KB) that the idealized model is actually achievable — the entire working set fits in shared memory or L1 cache of a modern GPU.
