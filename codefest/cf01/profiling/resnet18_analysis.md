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

