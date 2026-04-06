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

## Arithmetic Intensity Calculation (Standard Compulsory Model)
For the most MAC-intensive layer, **Conv2d: 1-1**, we calculate the Arithmetic Intensity ($AI$) based on the compulsory DRAM traffic. This assumes a model where the total volume of the input, weight, and output tensors are loaded from/written to DRAM once, representing the minimum data movement required for the operation.



### 1. Layer Specifications (Conv2d: 1-1)
* **Kernel:** $7 \times 7$ convolution, Stride 2.
* **Input Shape:** $[1, 3, 224, 224]$
* **Output Shape:** $[1, 64, 112, 112]$ (Total pixels: $802,816$)
* **Total Parameters:** $9,408$

### 2. Total Operations (Work)
Each MAC (Multiply-Accumulate) consists of 2 floating-point operations.
$$\text{Total Ops} = 2 \times 118,013,952 = 236,027,904 \text{ FLOPs}$$

### 3. Total DRAM Traffic (Compulsory Traffic)
We calculate the bytes moved for the entire tensor volumes. Each element is 4 bytes (FP32).

* **Input Bytes:** $3 \times 224 \times 224 \times 4 = 602,112 \text{ Bytes}$
* **Weight Bytes:** $64 \times 3 \times 7 \times 7 \times 4 = 37,632 \text{ Bytes}$
* **Output Bytes:** $64 \times 112 \times 112 \times 4 = 3,211,264 \text{ Bytes}$

$$\text{Total Bytes} = 602,112 + 37,632 + 3,211,264 = 3,851,008 \text{ Bytes}$$

### 4. Final Arithmetic Intensity Result
$$AI = \frac{\text{Total Operations}}{\text{Total Bytes}} = \frac{236,027,904}{3,851,008} \approx \mathbf{61.29 \text{ FLOPs/Byte}}$$



**Conclusion:** With an $AI$ of $\approx 61.29$, this layer is computationally dense relative to its data footprint. The high arithmetic intensity suggests that on most modern hardware, this layer will be **Compute-Bound**, provided the hardware architecture effectively manages the internal reuse of weights and input pixels to stay within the compulsory traffic limits.
