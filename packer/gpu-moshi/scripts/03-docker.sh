#!/bin/bash
# =============================================================================
# Docker with NVIDIA Container Runtime Installation
# =============================================================================
# Purpose: Install Docker with NVIDIA runtime for GPU container workloads
# =============================================================================

set -e

echo "=== [3/8] Docker with NVIDIA Container Runtime Installation ==="

export DEBIAN_FRONTEND=noninteractive

# Remove any existing Docker installation
echo "Removing existing Docker installation..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
rm -rf /var/lib/docker

# Install Docker dependencies
echo "Installing Docker dependencies..."
apt-get update -qq
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Add Docker GPG key
echo "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "Adding Docker repository..."
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists
apt-get update -qq

# Install Docker
echo "Installing Docker..."
apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Configure Docker daemon
echo "Configuring Docker daemon with NVIDIA runtime..."
mkdir -p /etc/docker

# Check if nvidia-container-runtime is available
if command -v nvidia-container-runtime &>/dev/null; then
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
    "storage-driver": "overlay2",
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-level": "info",
    "metrics-addr": "0.0.0.0:9323",
    "experimental": true,
    "features": {"buildkit": true}
}
EOF
else
    # Fallback without NVIDIA runtime
    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-level": "info",
    "metrics-addr": "0.0.0.0:9323",
    "experimental": true,
    "features": {"buildkit": true}
}
EOF
fi

# Create docker group and add ubuntu user
echo "Configuring Docker user groups..."
groupadd -f docker
usermod -aG docker ubuntu 2>/dev/null || true

# Enable and start Docker
echo "Starting Docker service..."
systemctl enable docker
systemctl start docker

# Configure Docker to start on boot
systemctl enable docker.service || true

# Verify Docker installation
echo "Verifying Docker installation..."
docker --version
docker compose version

# Test NVIDIA runtime
if command -v nvidia-container-runtime &>/dev/null; then
    echo "Testing NVIDIA container runtime..."
    docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi || echo "NVIDIA runtime test (expected to fail in build env)"
else
    echo "Warning: NVIDIA container runtime not available"
fi

# Install Docker cleanup utilities
echo "Installing Docker cleanup utilities..."
apt-get install -y -qq docker.io || true

# Create Docker cleanup script
cat > /usr/local/bin/docker-cleanup.sh << 'SCRIPT'
#!/bin/bash
# Docker cleanup script for disk space optimization

echo "Cleaning up Docker resources..."

# Remove stopped containers
docker container prune -f

# Remove unused networks
docker network prune -f

# Remove unused images
docker image prune -f

# Remove unused volumes
docker volume prune -f

# Remove build cache
docker builder prune -f

echo "Docker cleanup complete"
SCRIPT
chmod +x /usr/local/bin/docker-cleanup.sh

# Clean up
echo "Cleaning up..."
apt-get clean -qq
rm -rf /var/lib/apt/lists/*

echo "=== Docker Installation Complete ==="
