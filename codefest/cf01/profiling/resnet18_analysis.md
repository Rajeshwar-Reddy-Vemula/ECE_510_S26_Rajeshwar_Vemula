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

## Arithmetic Intensity ($AI$) Spectrum Analysis
For the dominant **Conv2d: 1-1** layer, the Arithmetic Intensity varies drastically depending on the hardware's ability to reuse data on-chip. We analyze three cases based on **Total Ops = 236,027,904**.



###  Standard Compulsory Model (Maximum Reuse)
**Assumption:** The hardware has sufficient SRAM to store all weights (37 KB) and implement a line buffer for pixels. Tensors are loaded/written to DRAM exactly once.
* **Traffic:** Input (602,112) + Weights (37,632) + Output (3,211,264) = **3,851,008 Bytes**.
* **Result:** $AI = \frac{236,027,904}{3,851,008} \approx \mathbf{61.29 \text{ FLOPs/Byte}}$
* **Classification:** **Compute-Bound.** 

###  Weight-Reloading Model (Partial Reuse)
**Assumption:** The hardware can buffer input pixels (Line Buffer) but lacks a Weight Cache. Weights must be re-fetched from DRAM for every spatial application ($112 \times 112$).
* **Traffic:** Weight Reloads (472,055,808) + Compulsory Activations (3,813,376) = **475,869,184 Bytes**.
* **Result:** $AI = \frac{236,027,904}{475,869,184} \approx \mathbf{0.496 \text{ FLOPs/Byte}}$
* **Classification:** **Memory-Bound.** 



### Absolute Zero-Reuse Model (No Reuse)
**Assumption:** The hardware has no internal SRAM. Every MAC operation requires a fresh DRAM fetch of the weight AND the specific $7 \times 7 \times 3$ input patch.
* **Traffic:** Weight Reloads (472,055,808) + Input Patch Reloads (472,055,808) + Outputs (3,211,264) = **947,322,880 Bytes**.
* **Result:** $AI = \frac{236,027,904}{947,322,880} \approx \mathbf{0.249 \text{ FLOPs/Byte}}$
* **Classification:** **Extreme Memory-Bound.** 

