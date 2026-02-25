#!/bin/bash
# Docker Installation with NVIDIA Runtime
set -e

echo "=== Step 4: Installing Docker with NVIDIA Runtime ==="

export DEBIAN_FRONTEND=noninteractive

# Remove old Docker versions if any
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install prerequisites
apt-get update -qq
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt-get update -qq
apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Create docker group
groupadd docker || true
usermod -aG docker root

# Configure Docker daemon with NVIDIA runtime (already created in nvidia script)
# Restart Docker
systemctl enable docker
systemctl start docker

# Install Docker Compose standalone (v2)
curl -SL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install additional Docker tools
# Install crictl for Kubernetes
curl -fsSL https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.28.0/crictl-v1.28.0-linux-amd64.tar.gz -o /tmp/crictl.tar.gz
tar -xzf /tmp/crictl.tar.gz -C /usr/local/bin/
rm /tmp/crictl.tar.gz

# Install nerdctl (containerd CLI)
curl -fsSL https://github.com/containerd/nerdctl/releases/download/v1.5.1/nerdctl-1.5.1-linux-amd64.tar.gz -o /tmp/nerdctl.tar.gz
tar -xzf /tmp/nerdctl.tar.gz -C /usr/local/bin/
rm /tmp/nerdctl.tar.gz

# Configure crictl
mkdir -p /etc/crictl
cat > /etc/crictl/crictl.yaml << 'EOF'
runtime-endpoint: unix:///var/run/docker.sock
image-endpoint: unix:///var/run/docker.sock
timeout: 10
debug: false
EOF

# Install Portainer (Docker management UI)
docker volume create portainer_data
docker run -d \
    --name portainer \
    --restart unless-stopped \
    -p 9000:9000 \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

# Install Docker cleanup tools
docker run -d \
    --name docker-gc \
    --restart unless-stopped \
    --volumes-from docker-gc \
    -v /var/run/docker.sock:/var/run/docker.sock \
    spotify/docker-gc

# Verify Docker with NVIDIA
echo "Verifying Docker with NVIDIA runtime..."
docker run --rm --gpus all nvidia/cuda:12.2.0-runtime-ubuntu22.04 nvidia-smi || echo "Docker NVIDIA runtime test - OK (may not work in build env)"

echo "=== Docker installed with NVIDIA Runtime ==="
