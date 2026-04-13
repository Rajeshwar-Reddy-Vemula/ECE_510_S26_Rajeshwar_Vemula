# Interface Selection and Bandwidth Analysis

**Project:** Ray-Object Intersection Accelerator Chiplet    

---

## Host platform

The assumed host is an **ARM Cortex-M7 class microcontroller** running
at 200 MHz, typical of an automotive ADAS co-processor or embedded
robotics vision unit (e.g. STM32H7, NXP i.MX RT series). This class
of host is widely used in edge inference applications where a full
Linux-capable SoC is too power-hungry but a bare-metal MCU needs
hardware acceleration for geometry computation. The MCU communicates
with the chiplet over a standard on-chip bus fabric.

---

## Chosen interface

**AXI4-Lite (control plane) + AXI4-Stream (data plane)**

AXI4-Lite is used to configure the chiplet before each frame: loading
sphere centers, box bounds, cylinder parameters, and disk parameters
into on-chip registers. These writes happen once per scene change, not
once per ray. AXI4-Stream is used to stream ray direction vectors into
the chiplet and receive intersection distances back. This pairing is
the ARM AMBA standard for exactly this split — control registers over
Lite, continuous data flow over Stream — and is supported natively on
all ARM Cortex-M and Cortex-A based SoC platforms.

---

## Bandwidth requirement calculation

**Target operating point:**

The hardware target is 50 million intersection tests per second at
50 MHz (1 result per clock cycle). This is the throughput at which
the chiplet reduces frame time from 13.98 s to ~0.14 s (99x speedup).

**Data per intersection test:**

Each test sends one ray direction vector (3 float32 values) and
receives one result (1 float32 distance value).

```
Input per test  : 3 floats × 4 bytes = 12 bytes
Output per test : 1 float  × 4 bytes =  4 bytes
Total per test  :                       16 bytes
```

Object parameters (sphere center + radius, box bounds, etc.) are
loaded once into on-chip registers at scene setup and reused for
all rays. They are NOT transferred per test.

**Required bandwidth:**

```
Throughput × data width = required bandwidth

Input  bandwidth = 50,000,000 tests/sec × 12 bytes = 600 MB/s
Output bandwidth = 50,000,000 tests/sec ×  4 bytes = 200 MB/s
Total required   =                                   800 MB/s
```

---

## Interface comparison

| Interface | Typical bandwidth | Meets 800 MB/s? | Notes |
|---|---|---|---|
| SPI | ~6 MB/s | No — 133x under | Only suitable for sensor config, not data streaming |
| I2C | ~0.4 MB/s | No — 2000x under | Far too slow for any data plane use |
| AXI4-Lite only | ~50 MB/s (32-bit @ 100 MHz) | No — 16x under | Control plane only, not suited for streaming |
| **AXI4-Stream 64-bit @ 100 MHz** | **800 MB/s** | **Exactly meets** | Natural fit for continuous ray streams |
| AXI4-Stream 64-bit @ 200 MHz | 1,600 MB/s | Yes — 2x margin | Conservative headroom option |
| PCIe Gen3 x1 | 8,000 MB/s | Yes — 10x over | Overkill; requires PCIe endpoint IP, large area |
| UCIe | ~100,000 MB/s | Yes — 125x over | Multi-die chiplet interconnect, not applicable here |

**Selected:** AXI4-Lite + AXI4-Stream at **100 MHz, 64-bit data bus**

At 64-bit bus width and 100 MHz:

```
AXI4-Stream bandwidth = 64 bits × 100 MHz
                      = 6,400 Mbit/s
                      = 800 MB/s
```

This exactly matches the requirement at the target throughput of
50M tests/sec with no margin. In practice the bus will not be 100%
utilised due to handshaking overhead (~10-15%), so the effective
throughput the chiplet can sustain is:

```
Effective throughput = 800 MB/s × 0.85 = 680 MB/s
Tests/sec at 85% bus utilisation = 680 MB/s / 12 bytes = 56.7M tests/sec
```

This is still above the 50M tests/sec target, so the interface is
not the bottleneck at the design operating point.

---

## Is the design interface-bound on the roofline?

**No — the design is compute-bound at the target operating point.**

Arithmetic intensity with on-chip parameter registers:

```
FLOPs per test (sphere, worst case) : 31
Bytes transferred per test (ray D only) : 12 bytes input + 4 bytes output = 16 bytes

AI = 31 FLOPs / 16 bytes = 1.94 FLOPs/byte
```

Ridge point of the chiplet roofline:

```
Peak compute  = 9 MACs × 50 MHz × 2 = 900 MFLOPs/s
Peak bandwidth = 800 MB/s (AXI4-Stream at 100 MHz, 64-bit)

Ridge point = 900 MFLOPs/s ÷ 800 MB/s = 1.125 FLOPs/byte
```

The kernel AI of 1.94 FLOPs/byte is above the ridge point of
1.125 FLOPs/byte, so the design sits in the compute-bound region.
The interface is not the bottleneck.

**Comparison with software baseline:**

The software baseline has AI = 0.63 FLOPs/byte (memory-bound) because
Python reloads all object parameters from DRAM on every call. The
hardware moves object parameters into on-chip registers, raising AI
from 0.63 to 1.94 — a 3x improvement in arithmetic intensity that
pushes the design above the ridge point.

If object parameters were NOT held in registers and were instead
streamed in with each ray, the bytes per test would increase to:

```
Ray D (12 bytes) + sphere params (16 bytes) = 28 bytes per test
AI = 31 / 28 = 1.11 FLOPs/byte  (below ridge point — interface-bound)
```

This quantifies the impact of the register file: without it the design
would be interface-bound at 1.11 FLOPs/byte and peak throughput would
be limited to 800 MB/s ÷ 28 bytes = 28.6M tests/sec instead of 50M.
The register file is therefore the critical architectural decision that
keeps the design compute-bound.

---

## Why not PCIe or UCIe?

PCIe Gen3 x1 provides 8 GB/s but requires a PCIe endpoint controller
IP block (~50,000 gates), a Root Complex on the host, and a full driver
stack. This is practical for a data-centre inference card but not for
an ARM Cortex-M based embedded system. UCIe targets multi-die
integration at wafer scale and is not relevant for a single-chiplet
design communicating with a host MCU.

## Why not SPI or I2C?

SPI at 50 Mbit/s provides only 6 MB/s — 133 times below the 800 MB/s
requirement. It would limit throughput to 6 MB/s ÷ 12 bytes = 500,000
tests/sec, which matches the software baseline and provides no speedup.
I2C is even slower and is appropriate only for sensor configuration at
low data rates.
