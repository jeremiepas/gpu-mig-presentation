#!/bin/bash
# GPU Driver Installation Script for Packer
# Installs NVIDIA drivers, CUDA, and GPU support tools

set -e

echo "=== Starting GPU driver installation ==="

# Detect GPU type
GPU_TYPE=$(lspci | grep -i nvidia | head -1)
echo "Detected GPU: $GPU_TYPE"

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# Install required packages
apt-get install -y -qq \
    build-essential \
    linux-headers-$(uname -r) \
    gcc \
    make \
    curl \
    wget \
    gnupg \
    software-properties-common \
    vim \
    git

# Add NVIDIA repository
echo "=== Adding NVIDIA repository ==="
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/3bf863cc.pub | apt-key add -
echo "deb https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/ /" > /etc/apt/sources.list.d/cuda.list

# Add NVIDIA driver repository
wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub | apt-key add -
echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" > /etc/apt/sources.list.d/cuda.list
echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub" > /etc/apt/sources.list.d/nvidia-driver.list

# Add NVIDIA Container Toolkit repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || true
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# Add NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list -o /etc/apt/sources.list.d/nvidia-docker.list

# Update repositories
apt-get update -qq

# Install NVIDIA driver and CUDA
echo "=== Installing NVIDIA driver and CUDA ==="
apt-get install -y -qq \
    nvidia-driver-535 \
    nvidia-utils-535 \
    nvidia-settings \
    cuda-toolkit-12-2 \
    nvidia-container-toolkit

# Install NVIDIA Container Toolkit
apt-get install -y -qq nvidia-container-toolkit

# Configure NVIDIA Container Runtime
nvidia-ctk runtime configure --runtime=docker
nvidia-ctk runtime configure --runtime=containerd

# Restart Docker
systemctl restart docker || true

# Load NVIDIA kernel modules
echo "=== Loading NVIDIA kernel modules ==="
modprobe nvidia
modprobe nvidia_uvm
modprobe nvidia_modeset

# Verify NVIDIA installation
echo "=== Verifying NVIDIA installation ==="
nvidia-smi || echo "Warning: nvidia-smi not available in build environment (expected)"
nvidia-container-cli list || echo "Warning: nvidia-container-cli not available in build environment"

# Add NVIDIA persistence daemon startup
systemctl enable nvidia-persistenced || true

# Install useful GPU tools
apt-get install -y -qq \
    gpu-burn \
    gpustat

echo "=== GPU driver installation complete ==="
