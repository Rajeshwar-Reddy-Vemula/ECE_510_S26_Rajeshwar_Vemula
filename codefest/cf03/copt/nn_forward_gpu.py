import torch
import torch.nn as nn

# Step 1: Detect GPU and print device name
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

if device.type == "cuda":
    print(f"CUDA GPU detected: {torch.cuda.get_device_name(0)}")
else:
    print("No CUDA GPU found. Exiting.")
    exit()

# Step 2: Define the network using nn.Sequential
# Architecture: 4 inputs -> 5 hidden neurons (ReLU) -> 1 linear output
model = nn.Sequential(
    nn.Linear(4, 5),    # Linear layer: 4 inputs -> 5 hidden
    nn.ReLU(),           # ReLU activation
    nn.Linear(5, 1)      # Linear layer: 5 hidden -> 1 output (no activation)
)

# Move model to GPU
model.to(device)
print(f"Model moved to: {next(model.parameters()).device}")

# Step 3: Generate random input tensor [16, 4] and move to GPU
input_tensor = torch.randn(16, 4).to(device)
print(f"Input tensor shape: {input_tensor.shape}")
print(f"Input tensor device: {input_tensor.device}")

# Run forward pass
output = model(input_tensor)

# Verify output shape and device
print(f"Output tensor shape: {output.shape}")
print(f"Output tensor device: {output.device}")
