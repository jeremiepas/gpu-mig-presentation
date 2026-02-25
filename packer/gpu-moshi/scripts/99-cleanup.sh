#!/bin/bash
# =============================================================================
# Cleanup & Finalize
# =============================================================================
# Purpose: Clean up build artifacts, reduce image size, finalize configuration
# =============================================================================

set -e

echo "=== [8/8] Cleanup & Finalize ==="

export DEBIAN_FRONTEND=noninteractive

# Clean apt cache
echo "Cleaning apt cache..."
apt-get clean -qq
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*

# Clean package manager cache
echo "Cleaning package manager cache..."
dpkg -l | grep -E "^rc" | awk '{print $2}' | xargs -r dpkg --purge || true
apt-get autoremove -y -qq || true

# Clean logs
echo "Cleaning logs..."
# Clean journal logs
journalctl --vacuum-time=1s 2>/dev/null || true
journalctl --vacuum-size=10M 2>/dev/null || true

# Clean log files
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
rm -rf /var/log/*.log
rm -rf /var/log/*.old
rm -rf /var/log/apt/history.log
rm -rf /var/log/apt/term.log

# Clean temporary files
echo "Cleaning temporary files..."
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /root/.cache
rm -rf /root/.local/share/Trash

# Clean package manager temp
rm -rf /var/cache/dpkg
rm -rf /var/cache/apt
rm -rf /var/cache/man

# Clean thumbnail cache
rm -rf /root/.cache/thumbnails
rm -rf /home/*/.cache/thumbnails 2>/dev/null || true

# Clean bash history
echo "Cleaning bash history..."
rm -f /root/.bash_history
rm -f /home/*/.bash_history 2>/dev/null || true

# Disable journal persistent storage to save space
echo "Configuring journal for minimal footprint..."
mkdir -p /var/log/journal
echo "SystemMaxUse=50M" > /etc/systemd/journald.conf
echo "RuntimeMaxUse=50M" >> /etc/systemd/journald.conf

# Clean Docker (if installed)
echo "Cleaning Docker..."
if command -v docker &>/dev/null; then
    # Remove all containers, images, volumes
    docker system prune -af --volumes 2>/dev/null || true
fi

# Clean pip cache
echo "Cleaning pip cache..."
rm -rf /root/.cache/pip
rm -rf /root/.cache/huggingface

# Clean git credential store
rm -rf /root/.git-credential-cache

# Clean npm cache (if present)
rm -rf /root/.npm 2>/dev/null || true

# Clean Nushhi cache
rm -rf /root/.cache/nushell 2>/dev/null || true

# Zero free space for better compression (optional)
# echo "Zeroing free space..."
# dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
# rm -f /EMPTY

# Sync filesystem
echo "Syncing filesystem..."
sync

# Print disk usage
echo ""
echo "=== Disk Usage ==="
df -h /

# Create system information file
echo "Creating system information..."
cat > /etc/moshi-image.info << EOF
# GPU Moshi Demo Image Information
# Generated: $(date)

IMAGE_NAME=gpu-moshi-demo-ubuntu-22.04
IMAGE_VERSION=1.0.0
BASE_OS=Ubuntu 22.04 LTS
NVIDIA_DRIVER=535
CUDA_VERSION=12.2
DOCKER_VERSION=$(docker --version 2>/dev/null || echo "N/A")
K3S_VERSION=v1.28.4+k3s2

COMPONENTS:
- NVIDIA Driver 535
- CUDA 12.2
- Docker with NVIDIA runtime
- K3s Kubernetes
- Moshi Python dependencies
- Security hardening applied

GPU_MODES:
- MIG (if supported by hardware)
- Time Slicing (4 replicas)

SERVICES:
- Docker (enabled)
- K3s (enabled)
- fail2ban (enabled)
- UFW firewall (enabled)

PORTS:
- 22/tcp: SSH
- 6443/tcp: K3s API
- 30090/tcp: Prometheus (optional)
- 30300/tcp: Grafana (optional)

UTILITY_SCRIPTS:
- gpu-status.sh: GPU status
- gpu-mig-status.sh: MIG status
- gpu-monitor.sh: GPU monitoring
- gpu-mode.sh: Switch GPU modes
- moshi-init.sh: Initialize Moshi
- moshi-verify.sh: Verify Moshi setup
- moshi-gpu-test.sh: Test GPU with PyTorch
- k3s-status.sh: K3s status
- k3s-restart.sh: Restart K3s
- docker-cleanup.sh: Clean Docker

EOF

# Set permissions
chmod 644 /etc/moshi-image.info

# Print final message
echo ""
echo "=== Image Build Complete ==="
echo ""
echo "Image information:"
cat /etc/moshi-image.info
echo ""
echo "The image is ready for deployment."
echo ""
echo "To use this image:"
echo "1. Deploy on Scaleway GPU instance (H100-1-80G)"
echo "2. SSH in as root or ubuntu user"
echo "3. Configure GPU mode: gpu-mode.sh timeslicing OR gpu-mode.sh mig"
echo "4. Start K3s workloads"
