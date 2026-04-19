==PROF== Connected to process 19877 (/content/gemm_naive)
==PROF== Profiling "gemm_naive" - 0: 0%....50%....100% - 6 passes
==PROF== Profiling "gemm_naive" - 1: 0%....50%....100% - 6 passes
=== Naive GEMM ===
Matrix size: 1024 x 1024
Kernel time: 1417.414 ms
Performance: 1.52 GFLOP/s
Max error vs CPU: 7.629395e-05
Verification: PASS
==PROF== Disconnected from process 19877
[19877] gemm_naive@127.0.0.1
  gemm_naive(const float *, const float *, float *, int) (64, 64, 1)x(16, 16, 1), Context 1, Stream 7, Device 0, CC 7.5
    Section: Command line profiler metrics
    -------------------------------------------------- ----------- ------------
    Metric Name                                        Metric Unit Metric Value
    -------------------------------------------------- ----------- ------------
    dram__bytes.sum                                          Mbyte       213.68
    dram__throughput.avg.pct_of_peak_sustained_elapsed           %         7.27
    sm__throughput.avg.pct_of_peak_sustained_elapsed             %        62.50
    -------------------------------------------------- ----------- ------------

  gemm_naive(const float *, const float *, float *, int) (64, 64, 1)x(16, 16, 1), Context 1, Stream 7, Device 0, CC 7.5
    Section: Command line profiler metrics
    -------------------------------------------------- ----------- ------------
    Metric Name                                        Metric Unit Metric Value
    -------------------------------------------------- ----------- ------------
    dram__bytes.sum                                          Mbyte       214.24
    dram__throughput.avg.pct_of_peak_sustained_elapsed           %         7.29
    sm__throughput.avg.pct_of_peak_sustained_elapsed             %        62.50
    -------------------------------------------------- ----------- ------------
