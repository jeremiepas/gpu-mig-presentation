#!/bin/bash
# Base packages installation script
set -e

echo "=== Step 1: Installing base packages ==="

export DEBIAN_FRONTEND=noninteractive

# Update repositories
apt-get update -qq

# Install base packages
apt-get install -y -qq \
    build-essential \
    curl \
    wget \
    vim \
    git \
    htop \
    tmux \
    tree \
    jq \
    unzip \
    zip \
    rsync \
    gnupg \
    ca-certificates \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    netcat-traditional \
    socat \
    iptables \
    bridge-utils \
    python3 \
    python3-pip \
    python3-venv

# Create swap file (optional for GPU workloads)
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Set timezone
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

# Disable predictive naming for network interfaces
echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash net.ifnames=0"' >> /etc/default/grub
update-grub

echo "=== Base packages installed ==="
