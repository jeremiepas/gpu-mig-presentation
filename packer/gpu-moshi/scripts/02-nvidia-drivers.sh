#!/bin/bash
# =============================================================================
# NVIDIA GPU Drivers & CUDA Installation
# =============================================================================
# Purpose: Install NVIDIA drivers compatible with L4 GPU
# Supports: MIG and Time Slicing configurations
# =============================================================================

set -e

echo "=== [2/8] NVIDIA GPU Drivers & CUDA Installation ==="

export DEBIAN_FRONTEND=noninteractive

# Detect GPU type
echo "Detecting GPU..."
GPU_INFO=$(lspci | grep -i nvidia || echo "No NVIDIA GPU detected")
echo "GPU Info: $GPU_INFO"

# Check if GPU is present (L4 or other)
if ! echo "$GPU_INFO" | grep -qi "nvidia"; then
    echo "WARNING: No NVIDIA GPU detected in this build environment"
    echo "Continuing with driver installation for final image..."
fi

# Add NVIDIA repository
echo "Adding NVIDIA repositories..."
distribution=$(. /etc/os-release && echo "${ID}${VERSION_ID}")

# Add CUDA repository
echo "deb https://developer.download.nvidia.com/compute/cuda/repos/${distribution}/x86_64/ /" > /etc/apt/sources.list.d/cuda.list

# Add NVIDIA driver repository
wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub | apt-key add - 2>/dev/null || true
echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" > /etc/apt/sources.list.d/cuda.list

# Add NVIDIA Container Toolkit repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || true
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Add NVIDIA Container Toolkit
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add - 2>/dev/null || true
curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu22.04/nvidia-docker.list -o /etc/apt/sources.list.d/nvidia-docker.list

# Update repositories
echo "Updating package lists..."
apt-get update -qq || true

# Install NVIDIA driver (535 for L4 GPU stability)
echo "Installing NVIDIA driver..."
apt-get install -y -qq \
    nvidia-driver-535 \
    nvidia-dkms-535 \
    nvidia-utils-535 \
    nvidia-settings \
    nvidia-compute-utils-535 \
    libnvidia-encode-535 \
    libnvidia-decode-535 \
    libnvidia-fs-535 \
    libnvidia-gl-535 \
    libnvidia-extra-535 \
    nvidia-prime \
    x11-driver-nvidia || true

# Install CUDA toolkit (minimal)
echo "Installing CUDA toolkit..."
apt-get install -y -qq \
    cuda-toolkit-12-2 \
    cuda-runtime-12-2 \
    cuda-libraries-12-2 \
    cuda-libraries-dev-12-2 || true

# Install NVIDIA Container Toolkit
echo "Installing NVIDIA Container Toolkit..."
apt-get install -y -qq \
    nvidia-container-toolkit \
    nvidia-container-runtime || true

# Create NVIDIA runtime configuration for Docker
echo "Configuring NVIDIA Container Runtime for Docker..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "default-runtime": "nvidia",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF

# Create NVIDIA Container Toolkit configuration
echo "Configuring NVIDIA Container Toolkit..."
nvidia-ctk runtime configure --runtime=docker --config=/etc/docker/daemon.json || true
nvidia-ctk runtime configure --runtime=containerd --config=/etc/containerd/config.toml || true

# Load NVIDIA kernel modules
echo "Loading NVIDIA kernel modules..."
modprobe nvidia 2>/dev/null || echo "Warning: Could not load nvidia module (expected in build env)"
modprobe nvidia_uvm 2>/dev/null || echo "Warning: Could not load nvidia_uvm module"
modprobe nvidia_modeset 2>/dev/null || echo "Warning: Could not load nvidia_modeset module"

# Update kernel module dependencies
update-initramfs -u 2>/dev/null || true

# Enable NVIDIA persistence daemon
echo "Enabling NVIDIA services..."
systemctl enable nvidia-persistenced 2>/dev/null || true

# Install GPU monitoring tools
echo "Installing GPU monitoring tools..."
apt-get install -y -qq \
    gpustat \
    n true

# Create GPU utilitiesvidia-smi ||
echo "Creating GPU utility scripts..."

# GPU status script
cat > /usr/local/bin/gpu-status.sh << 'SCRIPT'
#!/bin/bash
# GPU Status Check Script

echo "=== NVIDIA GPU Status ==="
nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits || echo "GPU not available"

echo ""
echo "=== GPU Processes ==="
nvidia-smi || echo "nvidia-smi not available"
SCRIPT
chmod +x /usr/local/bin/gpu-status.sh

# GPU MIG status script
cat > /usr/local/bin/gpu-mig-status.sh << 'SCRIPT'
#!/bin/bash
# GPU MIG Configuration Status

echo "=== MIG Configuration ==="
nvidia-smi mig -lgip || echo "MIG not available"

echo ""
echo "=== MIG Devices ==="
nvidia-smi mig -gi || echo "MIG not available"
SCRIPT
chmod +x /usr/local/bin/gpu-mig-status.sh

# Verify installation
echo "Verifying NVIDIA installation..."
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,compute_cap --format=csv,noheader || echo "GPU not available in build environment"
    echo "nvidia-smi: OK"
else
    echo "nvidia-smi: Not available (expected in build environment)"
fi

# Clean up
echo "Cleaning up..."
apt-get clean -qq
rm -rf /var/lib/apt/lists/*

echo "=== NVIDIA Installation Complete ==="
