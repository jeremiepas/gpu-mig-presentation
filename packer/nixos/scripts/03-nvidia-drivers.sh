#!/bin/bash
# NVIDIA GPU Drivers Installation
set -e

echo "=== Step 3: Installing NVIDIA GPU Drivers ==="

export DEBIAN_FRONTEND=noninteractive

# Detect GPU
GPU_MODEL=$(lspci | grep -i nvidia | head -1 | awk '{print $5, $6, $7, $8, $9}')
echo "Detected GPU: $GPU_MODEL"

# Add NVIDIA repositories
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)

# Add CUDA repository
wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/3bf863cc.pub | apt-key add - 2>/dev/null || true
echo "deb https://developer.download.nvidia.com/compute/cuda/repos/$distribution/x86_64/ /" > /etc/apt/sources.list.d/cuda.list

# Add NVIDIA driver repository
wget -qO - https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub | apt-key add - 2>/dev/null || true
echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" > /etc/apt/sources.list.d/nvidia-driver.list

# Add NVIDIA Container Toolkit repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable deb/\$(arch) /" | sed s/\$\(arch\)/x86_64/ > /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Update repositories
apt-get update -qq

# Install NVIDIA driver and CUDA toolkit
echo "Installing NVIDIA driver and CUDA..."
apt-get install -y -qq \
    nvidia-driver-535-server \
    nvidia-utils-535-server \
    nvidia-settings-535-server \
    nvidia-dkms-535-server \
    cuda-toolkit-12-2 \
    cuda-runtime-12-2 \
    nvidia-container-toolkit

# Install kernel headers
apt-get install -y -qq \
    linux-headers-$(uname -r) \
    linux-modules-extra-$(uname -r)

# Load NVIDIA kernel modules
echo "Loading NVIDIA kernel modules..."
modprobe nvidia
modprobe nvidia_uvm
modprobe nvidia_modeset
modprobe nvidia_drm

# Make modules load on boot
cat >> /etc/modules-load.d/nvidia.conf << 'EOF'
nvidia
nvidia_uvm
nvidia_modeset
nvidia_drm
EOF

# Configure NVIDIA Container Runtime for Docker
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
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "iptables": false,
  "ip6tables": false,
  "bridge": "none"
}
EOF

# Configure nvidia-container-runtime
mkdir -p /etc/nvidia-container-runtime
cat > /etc/nvidia-container-runtime/config.toml << 'EOF'
[nvidia-container-cli]
root = "/run/nvidia/driver"
path = "/usr/bin/nvidia-container-cli"
environment = [
  "NVIDIA_VISIBLE_DEVICES=all",
  "NVIDIA_DRIVER_CAPABILITIES=all"
]
debug = "/var/log/nvidia-container-runtime.log"

[nvidia-container-runtime]
runc = "/usr/bin/runc"
migrate-from-docker = true
EOF

# Create nvidia-persistenced service
cat > /etc/systemd/system/nvidia-persistenced.service << 'EOF'
[Unit]
Description=NVIDIA Persistence Daemon
After=syslog.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user nvidia-persistenced --no-persistence-mode --verbose
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nvidia-persistenced || true

# Install GPU monitoring tools
apt-get install -y -qq \
    gpustat \
    nvtop \
    gpu-burn

# Verify installation
echo "Verifying NVIDIA installation..."
nvidia-smi || echo "Note: nvidia-smi may not work in build environment"
echo "NVIDIA driver version: $(cat /proc/driver/nvidia/version 2>/dev/null || echo 'Driver info not available')"

echo "=== NVIDIA GPU Drivers installed ==="
