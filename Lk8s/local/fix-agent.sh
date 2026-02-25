#!/bin/bash
# Fix K3s Agent Configuration
# Run this on your NixOS machine (192.168.1.96)

set -e

echo "=== Fixing K3s Agent Configuration ==="
echo ""

# Stop existing agent
if systemctl is-active --quiet k3s-agent; then
  echo "Stopping K3s agent..."
  sudo systemctl stop k3s-agent
fi

# Create config directory
sudo mkdir -p /etc/rancher/k3s

# Copy config file
sudo cp /home/jeremie/Documents/perso/note/blog/mig-time-slincing/assets/gpu-mig-presentation/Lk8s/local/config.yaml /etc/rancher/k3s/config.yaml

# Start agent
sudo systemctl start k3s-agent

# Check status
echo ""
echo "Checking agent status..."
sudo systemctl status k3s-agent --no-pager

# Check logs
echo ""
echo "Agent logs (last 20 lines):"
sudo journalctl -u k3s-agent --no-pager -n 20
