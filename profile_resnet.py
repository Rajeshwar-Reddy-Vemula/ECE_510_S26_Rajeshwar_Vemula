import torch
from torchvision.models import resnet18
from torchinfo import summary
import os

# 1. Create the directory structure required for Step 2 of the assignment
os.makedirs("codefest/cf01/profiling", exist_ok=True)

# 2. Initialize the ResNet-18 model
model = resnet18()

# 3. Profile the model with correct column names (torchinfo 1.8+)
# Input size: (batch=1, channels=3, height=224, width=224)
# Note: 'node_name' is removed to avoid the ValueError
stats = summary(
    model, 
    input_size=(1, 3, 224, 224),
    col_names=["input_size", "output_size", "num_params", "mult_adds"],
    verbose=0
)

# 4. Save the full output to the required path for submission
output_path = "codefest/cf01/profiling/resnet18_profile.txt"
with open(output_path, "w") as f:
    f.write(str(stats))

print(f"Success! Profiling saved to {output_path}")
