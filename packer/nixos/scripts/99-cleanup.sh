#!/bin/bash
# Cleanup script - remove unnecessary files and optimize image
set -e

echo "=== Step 99: Cleanup ==="

export DEBIAN_FRONTEND=noninteractive

# Clean apt cache
echo "Cleaning apt cache..."
apt-get clean -qq
apt-get autoremove -y -qq
rm -rf /var/lib/apt/lists/*

# Clean log files
echo "Cleaning log files..."
rm -rf /var/log/*.log
rm -rf /var/log/*/*.log
rm -rf /var/log/*/*/*.log
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clean package manager cache
echo "Cleaning package manager cache..."
rm -rf /var/cache/apt/archives/*.deb
rm -rf /var/cache/pip/*
rm -rf ~/.cache/pip/*

# Clean Nix cache
echo "Cleaning Nix cache..."
nix-collect-garbage -d 2>/dev/null || true

# Remove SSH host keys (will be regenerated)
echo "Cleaning SSH host keys..."
rm -f /etc/ssh/ssh_host_*_key*
rm -f /root/.ssh/known_hosts

# Remove machine-id (will be regenerated)
echo "Cleaning machine-id..."
truncate -s 0 /etc/machine-id 2>/dev/null || true

# Remove bash history
echo "Cleaning bash history..."
rm -f /root/.bash_history
rm -f /home/*/.bash_history

# Clean Docker
echo "Cleaning Docker..."
docker system prune -f --volumes || true

# Remove temporary files
echo "Removing temporary files..."
rm -rf /tmp/packer-*
rm -rf /var/tmp/*

# Clean up cloud-init
echo "Cleaning cloud-init..."
cloud-init clean --logs || true

# Zero free space for better compression (optional)
# dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
# rm -f /EMPTY

# Sync filesystem
sync

echo "=== Cleanup complete ==="
