# ResNet-18 Profiling Analysis

## Top 5 MAC-Intensive Layers
The following table identifies the layers in ResNet-18 with the highest computational load (Mult-Adds) for a single FP32 forward pass with an input size of 3x224x224.

| Layer Name | MACs (Mult-Adds) | Parameter Count |
| :--- | :--- | :--- |
| **Conv2d: 1-1** | 118,013,952 | 9,408 |
| **Conv2d: 3-1** | 115,605,504 | 36,864 |
| **Conv2d: 3-4** | 115,605,504 | 36,864 |
| **Conv2d: 3-7** | 115,605,504 | 36,864 |
| **Conv2d: 3-10** | 115,605,504 | 36,864 |

---

# ResNet-18 Profiling Analysis

## Top 5 MAC-Intensive Layers
The following table identifies the layers in ResNet-18 with the highest computational load (Mult-Adds) for a single FP32 forward pass with an input size of 3x224x224.

| Layer Name | MACs (Mult-Adds) | Parameter Count |
| :--- | :--- | :--- |
| **Conv2d: 1-1** | 118,013,952 | 9,408 |
| **Conv2d: 3-1** | 115,605,504 | 36,864 |
| **Conv2d: 3-4** | 115,605,504 | 36,864 |
| **Conv2d: 3-7** | 115,605,504 | 36,864 |
| **Conv2d: 3-10** | 115,605,504 | 36,864 |

---

## Arithmetic Intensity Calculation (Strict No-Reuse Model)
For the most MAC-intensive layer, **Conv2d: 1-1**, we calculate the Arithmetic Intensity ($AI$) under the strict hardware constraint of **no on-chip cache and no data reuse**. In this scenario, every operand (weights and inputs) must be re-fetched from DRAM for every calculation.

### 1. Layer Specifications (Conv2d: 1-1)
* **Kernel:** $7 \times 7$ convolution, Stride 2.
* **Input Shape:** $[1, 3, 224, 224]$
* **Output Shape:** $[1, 64, 112, 112]$ (Total pixels: $802,816$)
* **Weights per Receptive Field:** $7 \times 7 \times 3 = 147$

### 2. Total Operations (Work)
Each MAC (Multiply-Accumulate) consists of 2 floating-point operations.
$$\text{Total Ops} = 2 \times 118,013,952 = 236,027,904 \text{ FLOPs}$$

### 3. Total DRAM Traffic (No-Reuse Constraint)
Under strict no-reuse, we calculate the bytes moved for every spatial application of the filters. Each element is 4 bytes (FP32).

* **Weight Traffic:** $802,816 \text{ outputs} \times 147 \text{ weights} \times 4 \text{ bytes} = 472,055,808 \text{ Bytes}$
* **Input Traffic:** $802,816 \text{ outputs} \times 147 \text{ inputs} \times 4 \text{ bytes} = 472,055,808 \text{ Bytes}$
* **Output Traffic:** $802,816 \text{ outputs} \times 1 \text{ pixel} \times 4 \text{ bytes} = 3,211,264 \text{ Bytes}$

$$\text{Total Bytes} = 472,055,808 + 472,055,808 + 3,211,264 = 947,322,880 \text{ Bytes}$$

### 4. Final Arithmetic Intensity Result
$$AI = \frac{\text{Total Operations}}{\text{Total Bytes}} = \frac{236,027,904}{947,322,880} \approx \mathbf{0.249 \text{ Ops/Byte}}$$

**Conclusion:** With an $AI$ of $\approx 0.25$, this layer is heavily **Memory-Bound**. Without on-chip SRAM to reuse weights or input pixels, the hardware spends the vast majority of its time fetching redundant data from DRAM rather than performing computation.
