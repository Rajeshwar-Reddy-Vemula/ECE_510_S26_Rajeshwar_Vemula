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

## Arithmetic Intensity Analysis: Conv2d 1-1
This analysis characterizes the operational efficiency of the most computationally expensive layer in the network.

### 1. Hardware Assumptions (Weight-Reloading Model)
To determine the lower bound of efficiency, we assume a **Zero Weight-Reuse** hardware model. The specific architectural constraints are as follows:
* **No Weight Cache:** The hardware lacks a register file or SRAM to store the filter kernels. Every time the convolution sliding window moves to a new spatial location, the entire $7 \times 7 \times 3$ filter must be re-fetched from DRAM.
* **Perfect Activation Reuse:** The hardware possesses enough internal buffering (e.g., a Line Buffer) to load the input image into the chip exactly once and write the output feature map to DRAM exactly once.



### 2. Calculation of Work (FLOPs)
Each Multiply-Accumulate (MAC) operation consists of one multiplication and one addition.
* **Total MACs:** $118,013,952$
* **Total Operations:** $2 \times 118,013,952 = \mathbf{236,027,904 \text{ FLOPs}}$

### 3. Calculation of Memory Traffic (Bytes)
Data movement is calculated based on FP32 precision (4 bytes per element).

* **Weight Traffic (Zero Reuse):**
  Since weights are re-loaded for every MAC operation:
  $Traffic_{weights} = 118,013,952 \text{ MACs} \times 4 \text{ bytes} = 472,055,808 \text{ Bytes}$

* **Activation Traffic (Compulsory):**
  Input and Output tensors are moved across the DRAM bus exactly once:
  $Input \text{ Elements} = 3 \times 224 \times 224 = 150,528$
  $Output \text{ Elements} = 64 \times 112 \times 112 = 802,816$
  $Traffic_{activations} = (150,528 + 802,816) \times 4 \text{ bytes} = 3,813,376 \text{ Bytes}$

* **Total DRAM Traffic:**
  $Total \text{ Bytes} = 472,055,808 + 3,813,376 = \mathbf{475,869,184 \text{ Bytes}}$

### 4. Final Arithmetic Intensity ($AI$)
$$AI = \frac{\text{Total Operations}}{\text{Total Bytes}} = \frac{236,027,904}{475,869,184} \approx \mathbf{0.496 \text{ FLOPs/Byte}}$$

---

## Conclusion
Under the assumption that weights cannot be reused on-chip, the Arithmetic Intensity collapses from the algorithmic peak of ~61.3 down to **0.496**. This result demonstrates that the layer is strictly **Memory-Bound** in this hardware configuration. To achieve higher performance, the architecture must implement a weight-stationary dataflow or a weight cache to eliminate the redundant 472 MB of DRAM traffic.
