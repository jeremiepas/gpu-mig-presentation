#!/bin/bash
# K3s Agent Join Script for NixOS
# Usage: ./join-k3s-agent.sh <K3S_SERVER_IP> <AGENT_TOKEN> [NODE_NAME]
#
# Prerequisites:
#   1. Tailscale must be running and connected
#   2. K3s server must have Tailscale set up
#   3. You need the agent token from the K3s server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== K3s Agent Join Script for NixOS ===${NC}"

# Default values
K3S_NODE_NAME="nixos-agent"

# Parse arguments
if [ -z "$1" ]; then
  echo -e "${RED}Error: K3s server IP required${NC}"
  echo "Usage: $0 <K3S_SERVER_IP> <AGENT_TOKEN> [NODE_NAME]"
  echo ""
  echo "Example:"
  echo "  $0 100.64.0.1 'K10a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0@#\$%^&*()' nixos-gpu"
  exit 1
fi

K3S_SERVER_IP="$1"
AGENT_TOKEN="$2"

if [ -n "$3" ]; then
  K3S_NODE_NAME="$3"
fi

echo "K3s Server: $K3S_SERVER_IP"
echo "Node Name: $K3S_NODE_NAME"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Warning: Not running as root. Some operations may fail.${NC}"
  echo "Consider running with: sudo $0 ..."
  echo ""
fi

# Check Tailscale connection
echo -e "${YELLOW}Checking Tailscale connection...${NC}"
if command -v tailscale &> /dev/null; then
  TAILSCALE_STATUS=$(sudo tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "unknown")
  echo "Tailscale status: $TAILSCALE_STATUS"
  
  if [ "$TAILSCALE_STATUS" != "Running" ]; then
    echo -e "${YELLOW}Warning: Tailscale is not Running${NC}"
    echo "Please run: sudo tailscale up"
    echo ""
  fi
  
  # Get local Tailscale IP
  LOCAL_TAILSCALE_IP=$(sudo tailscale ip -4 2>/dev/null || echo "")
  echo "Local Tailscale IP: $LOCAL_TAILSCALE_IP"
else
  echo -e "${RED}Error: Tailscale not installed${NC}"
  echo "Please install Tailscale first. See nixos-tailscale.nix"
  exit 1
fi

# Check K3s server connectivity
echo ""
echo -e "${YELLOW}Checking K3s server connectivity...${NC}"
if nc -z -w5 "$K3S_SERVER_IP" 6443 2>/dev/null; then
  echo -e "${GREEN}K3s server is reachable on port 6443${NC}"
else
  echo -e "${RED}Error: Cannot reach K3s server on $K3S_SERVER_IP:6443${NC}"
  echo "Make sure Tailscale is connected and the server is running."
  exit 1
fi

# Check if K3s is already installed
echo ""
echo -e "${YELLOW}Checking K3s installation...${NC}"
if command -v k3s &> /dev/null; then
  echo "K3s is already installed"
  K3S_VERSION=$(k3s --version)
  echo "Version: $K3S_VERSION"
  
  # Check if already joined
  if systemctl is-active --quiet k3s-agent; then
    echo -e "${YELLOW}Warning: K3s agent is already running!${NC}"
    read -p "Do you want to restart and rejoin? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Exiting."
      exit 0
    fi
    echo "Stopping existing K3s agent..."
    sudo systemctl stop k3s-agent || true
  fi
else
  echo "K3s will be installed automatically"
fi

# Join the cluster
echo ""
echo -e "${GREEN}Joining K3s cluster...${NC}"

# Set environment variables for K3s agent
export K3S_URL="https://$K3S_SERVER_IP:6443"
export K3S_AGENT_TOKEN="$AGENT_TOKEN"
export K3S_NODE_NAME="$K3S_NODE_NAME"

# Install and start K3s agent
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

# Enable and start the agent
sudo systemctl enable k3s-agent
sudo systemctl start k3s-agent

# Wait for node to register
echo ""
echo -e "${YELLOW}Waiting for node to register...${NC}"
sleep 5

# Check node status
echo ""
echo -e "${GREEN}Node registration status:${NC}"
sudo k3s agent ready || true

# Get kubeconfig
echo ""
echo -e "${YELLOW}Copying kubeconfig to ~/.kube/config...${NC}"
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
sed -i "s|127.0.0.1|$K3S_SERVER_IP|g" ~/.kube/config

echo ""
echo -e "${GREEN}=== K3s Agent Joined Successfully! ===${NC}"
echo ""
echo "You can now use kubectl to interact with the cluster:"
echo "  kubectl get nodes"
echo ""
echo "The K3s server should now show your node when you run:"
echo "  kubectl get nodes -o wide"
