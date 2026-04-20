# CMAN — DRAM Traffic Analysis: Naive vs. Tiled Matrix Multiply

## Setup

- **N** = 32 (matrix dimension)
- **T** = 8 (tile size)
- **FP32** = 4 bytes per element
- **DRAM Bandwidth** = 320 GB/s
- **Compute** = 10 TFLOPS

---

## 1. Naive Triple Loop (ijk order)

```python
for i in 0..N:
  for j in 0..N:
    for k in 0..N:
      C[i][j] += A[i][k] * B[k][j]
```

For one output element C[i][j], the inner k-loop reads:
- A[i][k] for k = 0 to N−1 → **N reads from A**
- B[k][j] for k = 0 to N−1 → **N reads from B**

**Accesses per element of B = N = 32**

Total DRAM traffic (no reuse, each access = 4 bytes, plus one write of $N^2$ elements for C):
- **Total accesses:** $2N^3 = 65,536$
- **Total Bytes ($T_{naive}$):** $(2N^3 + N^2) \times 4 = 266,240 \text{ bytes} \approx 260 \text{ KB}$

---

## 2. Tiled Loop (tile size T = 8)

### Traditional tiling (T-times reuse per tile load)
Each element is loaded $N/T = 4$ times from DRAM, plus one write of C:
- **Total Bytes ($T_{tiled\_trad}$):** $(2N^3/T + N^2) \times 4 = 36,864 \text{ bytes} \approx 36 \text{ KB}$

### Ideal shared memory reuse (each element loaded once)
With sufficient on-chip memory, each element of A, B, and C is loaded/stored exactly once:
- **Total Bytes ($T_{tiled\_ideal}$):** $3N^2 \times 4 = 12,288 \text{ bytes} \approx 12 \text{ KB}$

---

## 3. Traffic Ratio (Naive vs. Ideal)

$$\frac{T_{naive}}{T_{tiled\_ideal}} \approx \frac{2N^3}{3N^2} \approx \frac{2N}{3}$$

**Explanation:** In the naive loop, each element is loaded from DRAM $N$ times, while ideal tiling loads each element once and reuses it on-chip, reducing DRAM traffic by a factor proportional to $N$.

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
