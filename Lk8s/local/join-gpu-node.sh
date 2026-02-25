#!/bin/bash
# K3s Agent Join Script for Local NixOS Machine
# Joins to Scaleway K3s cluster via Tailscale VPN
# GPU-specific configuration

set -e

# Configuration
K3S_SERVER_IP="100.119.182.72"
K3S_AGENT_TOKEN="K10e978259227d95ce11b56917280023c0be0db2e40a4cac1b0e5a9013a7b6f814f::server:183a224ac7673f9077cbf01c6d1e11fd"
NODE_NAME="nixos-gpu"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Joining K3s Cluster as GPU Node ===${NC}"
echo "Server: $K3S_SERVER_IP"
echo "Node: $NODE_NAME"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Warning: Running without root. Use sudo for full functionality.${NC}"
fi

# Check Tailscale
echo -e "${YELLOW}Checking Tailscale...${NC}"
if command -v tailscale &> /dev/null; then
  STATUS=$(sudo tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "unknown")
  echo "Tailscale status: $STATUS"
  
  if [ "$STATUS" != "Running" ]; then
    echo "Starting Tailscale..."
    sudo tailscale up
    sleep 3
  fi
  
  LOCAL_IP=$(sudo tailscale ip -4 2>/dev/null || echo "")
  echo "Local Tailscale IP: $LOCAL_IP"
else
  echo -e "${RED}Tailscale not installed!${NC}"
  echo "Install on NixOS with:"
  echo "  services.tailscale.enable = true;"
  exit 1
fi

# Test connectivity
echo ""
echo -e "${YELLOW}Testing K3s server connectivity...${NC}"
if nc -z -w5 "$K3S_SERVER_IP" 6443 2>/dev/null; then
  echo -e "${GREEN}K3s server is reachable!${NC}"
else
  echo -e "${RED}Cannot reach K3s server!${NC}"
  echo "Make sure Tailscale is connected on both sides"
  exit 1
fi

# Install K3s agent
echo ""
echo -e "${GREEN}Installing K3s agent...${NC}"

export K3S_URL="https://$K3S_SERVER_IP:6443"
export K3S_AGENT_TOKEN="$K3S_AGENT_TOKEN"
export K3S_NODE_NAME="$NODE_NAME"

curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

# Enable and start
sudo systemctl enable k3s-agent
sudo systemctl start k3s-agent

# Wait for node to register
echo ""
echo -e "${YELLOW}Waiting for node to register...${NC}"
sleep 10

# Add GPU labels and taints
echo ""
echo -e "${GREEN}Adding GPU labels and taints...${NC}"

# Wait for node to appear
for i in {1..30}; do
  if kubectl get node "$NODE_NAME" &>/dev/null; then
    break
  fi
  sleep 2
done

# Add labels
kubectl label node "$NODE_NAME" --overwrite \
  node-role.kubernetes.io/gpu="true" \
  nvidia.com/gpu.present="true" \
  gpu.local.dev="true" \
  hardware.type="nvidia-gpu"

# Add taints (so only GPU workloads can be scheduled)
kubectl taint node "$NODE_NAME" \
  nvidia.com/gpu=present:NoSchedule

# Verify
echo ""
echo -e "${GREEN}=== Node Details ===${NC}"
kubectl get node "$NODE_NAME" -o wide
kubectl get node "$NODE_NAME" -o json | jq '.metadata.labels'
kubectl get node "$NODE_NAME" -o json | jq '.spec.taints'

echo ""
echo -e "${GREEN}=== GPU Node Joined Successfully! ===${NC}"
echo ""
echo "Now you can deploy GPU workloads with:"
echo "  kubectl apply -f k8s/..."
echo ""
echo "Workloads must include tolerations for the GPU taint:"
echo "  tolerations:"
echo "    - key: nvidia.com/gpu"
echo "      operator: Exists"
echo "      effect: NoSchedule"
