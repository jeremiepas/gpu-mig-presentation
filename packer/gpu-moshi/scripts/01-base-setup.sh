#!/bin/bash
# =============================================================================
# Base System Setup & Security Hardening
# =============================================================================
# Purpose: Update system, install essential packages, basic security
# Base: Ubuntu 22.04 LTS
# =============================================================================

set -e

echo "=== [1/8] Base System Setup & Security Hardening ==="

# Prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Update package lists
echo "Updating package lists..."
apt-get update -qq

# Upgrade system
echo "Upgrading system packages..."
apt-get upgrade -y -qq

# Install essential packages
echo "Installing essential packages..."
apt-get install -y -qq \
    build-essential \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    jq \
    rsync \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    unzip \
    tzdata \
    libssl3 \
    iptables \
    iproute2

# Install tools for GPU monitoring
echo "Installing GPU monitoring tools..."
apt-get install -y -qq \
    pciutils \
    lm-sensors

# Set timezone
echo "Setting timezone to UTC..."
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

# Create application user (for non-root operations)
echo "Creating application user..."
if ! id -u ubuntu &>/dev/null; then
    useradd -m -s /bin/bash -G docker,video ubuntu || true
fi

# Configure system limits
echo "Configuring system limits..."
cat > /etc/security/limits.d/99-gpu.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
root soft nofile 65536
root hard nofile 65536
EOF

# Configure kernel parameters for GPU workloads
echo "Configuring kernel parameters..."
cat > /etc/sysctl.d/99-gpu.conf << 'EOF'
# Network settings
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 4096

# Memory settings for GPU workloads
vm.max_map_count = 262144
vm.swappiness = 1

# File descriptors
fs.file-max = 65536
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-gpu.conf || true

# Configure journald for persistent logging
echo "Configuring journald..."
mkdir -p /var/log/journal
echo "SystemMaxUse=100M" >> /etc/systemd/journald.conf
echo "SystemMaxFiles=5" >> /etc/systemd/journald.conf

# Disable unnecessary services
echo "Disabling unnecessary services..."
systemctl mask --now snapd.service || true
systemctl mask --now snapd.socket || true

# Clean up apt cache
echo "Cleaning up apt cache..."
apt-get clean -qq
rm -rf /var/lib/apt/lists/*

echo "=== Base System Setup Complete ==="
