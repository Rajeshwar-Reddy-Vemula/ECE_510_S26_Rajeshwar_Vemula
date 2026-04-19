#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define N 1024

// Naive GEMM kernel: one thread computes one element of C
__global__ void gemm_naive(const float *A, const float *B, float *C, int n) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    if (row < n && col < n) {
        float sum = 0.0f;
        for (int k = 0; k < n; k++) {
            sum += A[row * n + k] * B[k * n + col];
        }
        C[row * n + col] = sum;
    }
}

// Reference CPU matmul for verification
void matmul_cpu(const float *A, const float *B, float *C, int n) {
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            float sum = 0.0f;
            for (int k = 0; k < n; k++)
                sum += A[i * n + k] * B[k * n + j];
            C[i * n + j] = sum;
        }
}

int main() {
    size_t bytes = N * N * sizeof(float);

    // Allocate host memory
    float *h_A = (float *)malloc(bytes);
    float *h_B = (float *)malloc(bytes);
    float *h_C = (float *)malloc(bytes);
    float *h_C_ref = (float *)malloc(bytes);

    // Initialize matrices with random values
    srand(42);
    for (int i = 0; i < N * N; i++) {
        h_A[i] = (float)(rand() % 100) / 100.0f;
        h_B[i] = (float)(rand() % 100) / 100.0f;
    }

    // Allocate device memory
    float *d_A, *d_B, *d_C;
    cudaMalloc(&d_A, bytes);
    cudaMalloc(&d_B, bytes);
    cudaMalloc(&d_C, bytes);

    // Copy to device
    cudaMemcpy(d_A, h_A, bytes, cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, bytes, cudaMemcpyHostToDevice);

    // Launch config: 16x16 threads per block
    dim3 blockDim(16, 16);
    dim3 gridDim((N + blockDim.x - 1) / blockDim.x,
                 (N + blockDim.y - 1) / blockDim.y);

    // Warmup
    gemm_naive<<<gridDim, blockDim>>>(d_A, d_B, d_C, N);
    cudaDeviceSynchronize();

    // Timed run
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    gemm_naive<<<gridDim, blockDim>>>(d_A, d_B, d_C, N);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float ms = 0.0f;
    cudaEventElapsedTime(&ms, start, stop);

    // Compute GFLOP/s: 2*N^3 FLOPs for matmul
    double flops = 2.0 * (double)N * (double)N * (double)N;
    double gflops = (flops / (ms / 1000.0)) / 1e9;

    printf("=== Naive GEMM ===\n");
    printf("Matrix size: %d x %d\n", N, N);
    printf("Kernel time: %.3f ms\n", ms);
    printf("Performance: %.2f GFLOP/s\n", gflops);

    // Copy result back
    cudaMemcpy(h_C, d_C, bytes, cudaMemcpyDeviceToHost);

    // Verify against CPU (check a few elements)
    matmul_cpu(h_A, h_B, h_C_ref, N);
    float max_err = 0.0f;
    for (int i = 0; i < N * N; i++) {
        float err = fabsf(h_C[i] - h_C_ref[i]);
        if (err > max_err) max_err = err;
    }
    printf("Max error vs CPU: %e\n", max_err);
    printf("Verification: %s\n", max_err < 1e-2 ? "PASS" : "FAIL");

    // Cleanup
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);
    free(h_A);
    free(h_B);
    free(h_C);
    free(h_C_ref);

    return 0;
}
