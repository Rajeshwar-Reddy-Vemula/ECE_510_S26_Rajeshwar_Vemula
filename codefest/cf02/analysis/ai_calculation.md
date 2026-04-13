# Arithmetic Intensity Calculation
## Algorithm: Ray tracer city scene — dominant kernels
## Platform: WSL2 x86-64, Python 3 / NumPy, scene_city.json, 30 frames

---

## Dominant kernel: intersect_box (263.9s, 17.5% of runtime)

### FLOPs per call — slab method, 3 axis pairs

```
Per axis (×3):
  lo[i] = C[i] - hs[i]          1 sub
  hi[i] = C[i] + hs[i]          1 add
  t1 = (lo[i] - O[i]) / D[i]    1 sub + 1 div
  t2 = (hi[i] - O[i]) / D[i]    1 sub + 1 div
  swap + tmin/tmax compare       2 cmp
  subtotal per axis:             8 FLOPs

3 axes:                         24 FLOPs
tmin >= 0 check + t select:      2 FLOPs
Total: 26 FLOPs/call
```

### Bytes per call (float32, no cache reuse)

```
O  (ray origin):    3 × 4 = 12 bytes
D  (ray direction): 3 × 4 = 12 bytes
C  (box center):    3 × 4 = 12 bytes
hs (half size):     3 × 4 = 12 bytes
t  (result):        1 × 4 =  4 bytes (write)
Total: 52 bytes
```

### AI = 26 / 52 = 0.50 FLOPs/byte

---

## Second kernel: intersect_sphere (96.9s, 6.4%)

### FLOPs per call — quadratic formula

```
OS = O - S                       3 sub
a  = dot(D,D)                    3 mul + 2 add = 5
b  = 2*dot(D,OS)                 3 mul + 2 add + 1 mul = 6
c  = dot(OS,OS) - R*R            3 mul + 2 add + 1 mul + 1 sub = 7
disc = b*b - 4*a*c               2 mul + 1 sub = 3
sqrt(disc)                       1 sqrt
q, t0, t1                        1 add + 2 div = 3
comparisons                      2 cmp
Total: 3+5+6+7+3+1+3+2 = 30 FLOPs/call
```

### Bytes per call

```
O (ray origin):  12 bytes
D (ray dir):     12 bytes
S (center):      12 bytes
R (radius):       4 bytes
t (result):       4 bytes write
Total: 44 bytes
```

### AI = 30 / 44 = 0.68 FLOPs/byte

---

## Third kernel: intersect_cylinder (97.2s, 6.5%)

### FLOPs per call

```
oc = O - C                       3 sub
XZ quadratic:
  a = dx*dx + dz*dz              2 mul + 1 add = 3
  b = 2*(ox*dx + oz*dz)          2 mul + 1 add + 1 mul = 4
  c = ox*ox + oz*oz - R*R        2 mul + 1 add + 1 mul + 1 sub = 5
  disc = b*b - 4*a*c             2 mul + 1 sub = 3
  sqrt(disc)                     1
  t1, t2                         2 add + 2 div = 4
height bounds check (×2):        2 mul + 2 cmp = 4
cap tests (×2):                  2 sub + 2 div + 2 mul + 2 add + 2 cmp = 10
normal:                          2 div = 2
Total: 3+3+4+5+3+1+4+4+10+2 = 39 FLOPs/call
```

### Bytes per call

```
O: 12, D: 12, C: 12, R: 4, hh: 4, t: 4 write = 48 bytes
```

### AI = 39 / 48 = 0.81 FLOPs/byte

---

## normalize (73.9s, 4.9%)

```
FLOPs: dot(x,x) = 3 mul + 2 add = 5, sqrt = 1, x/n = 3 div → 9 FLOPs
Bytes: 3 floats read + 3 write = 24 bytes
AI = 9 / 24 = 0.38 FLOPs/byte
```

---

## Weighted arithmetic intensity (whole program, 30 frames)

| Kernel            | ncalls      | FLOPs/call | Total GFLOPs | Bytes/call | Total GB   |
|-------------------|-------------|-----------|-------------|-----------|-----------|
| intersect_box     | 39,038,423  | 26        | 1.015       | 52        | 2.030     |
| intersect_sphere  | 66,320,973  | 30        | 1.990       | 44        | 2.918     |
| intersect_cylinder| 39,704,759  | 39        | 1.548       | 48        | 1.906     |
| intersect_disk    | 13,233,675  | 30        | 0.397       | 56        | 0.741     |
| normalize         | 52,898,527  |  9        | 0.476       | 24        | 1.270     |
| **Total**         |             |           | **5.426**   |           | **8.865** |

```
Weighted AI = 5.426 GFLOPs / 8.865 GB = 0.61 FLOPs/byte
```

**All kernels are memory-bound (AI < ridge point ~4.5 FLOPs/byte).**

---

## Hardware design point (with on-chip registers)

Object parameters loaded once into registers. Only ray direction D
streamed per test (12 bytes in + 4 bytes out = 16 bytes).

```
sphere AI_hw = 30 / 16 = 1.88 FLOPs/byte
box    AI_hw = 26 / 16 = 1.63 FLOPs/byte
```

Ridge point of chiplet (sky130 HD, 50 MHz):
```
Peak compute  = 9 MACs × 50 MHz × 2 = 900 MFLOPs/s
Peak bandwidth = 800 MB/s (AXI4-Stream 64-bit @ 100 MHz)
Ridge point   = 900 / 800 = 1.125 FLOPs/byte
```

Hardware AI (1.63–1.88) > ridge point (1.125) → **compute-bound**.
