#!/bin/bash
# Complete K3s Agent Reset and Reinstall
# Run this on your NixOS machine (192.168.1.96)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=== COMPLETE K3s AGENT RESET ===${NC}"
echo ""

# Stop and disable existing services
echo -e "${YELLOW}Step 1: Stopping existing K3s services...${NC}"
for service in k3s k3s-agent; do
  if systemctl is-active --quiet "$service"; then
    echo "Stopping $service..."
    sudo systemctl stop "$service"
    sudo systemctl disable "$service"
  fi
done

# Remove K3s installation
echo ""
echo -e "${YELLOW}Step 2: Removing K3s installation...${NC}"
sudo /usr/local/bin/k3s-agent-uninstall.sh || true
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /var/lib/rancher/k3s
sudo rm -f /usr/local/bin/k3s*

# Clean up systemd
echo ""
echo -e "${YELLOW}Step 3: Cleaning up systemd...${NC}"
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Verify cleanup
echo ""
echo -e "${YELLOW}Step 4: Verifying cleanup...${NC}"
if command -v k3s &>/dev/null; then
  echo -e "${RED}Warning: K3s binaries still exist${NC}"
else
  echo -e "${GREEN}K3s binaries removed${NC}"
fi

# Check Tailscale
echo ""
echo -e "${YELLOW}Step 5: Checking Tailscale...${NC}"
if command -v tailscale &>/dev/null; then
  STATUS=$(sudo tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "unknown")
  echo "Tailscale status: $STATUS"
  
  if [ "$STATUS" != "Running" ]; then
    echo "Starting Tailscale..."
    sudo tailscale up
    sleep 3
  fi
  
  LOCAL_IP=$(sudo tailscale ip -4 2>/dev/null || echo "not assigned")
  echo "Local Tailscale IP: $LOCAL_IP"
else
  echo -e "${RED}Tailscale not installed!${NC}"
  echo "Please install Tailscale first"
  exit 1
fi

# Install fresh K3s agent
echo ""
echo -e "${GREEN}Step 6: Installing fresh K3s agent...${NC}"

export K3S_URL="https://100.119.182.72:6443"
export K3S_AGENT_TOKEN="K10e978259227d95ce11b56917280023c0be0db2e40a4cac1b0e5a9013a7b6f814f::server:183a224ac7673f9077cbf01c6d1e11fd"
export K3S_NODE_NAME="nixos-gpu"

curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

# Add GPU labels and taints via config file
sudo mkdir -p /etc/rancher/k3s

cat > /tmp/config.yaml << 'EOF'
server: https://100.119.182.72:6443
token: "K10e978259227d95ce11b56917280023c0be0db2e40a4cac1b0e5a9013a7b6f814f::server:183a224ac7673f9077cbf01c6d1e11fd"
node-name: nixos-gpu
node-label:
  - "nvidia.com/gpu=true"
  - "gpu=true"
  - "hardware.type=nvidia-gpu"
node-taint:
  - "nvidia.com/gpu=true:NoSchedule"
EOF

sudo cp /tmp/config.yaml /etc/rancher/k3s/config.yaml

# Start agent
sudo systemctl enable k3s-agent
sudo systemctl start k3s-agent

# Verify
echo ""
echo -e "${GREEN}Step 7: Verifying installation...${NC}"
sudo systemctl status k3s-agent --no-pager

# Check logs
echo ""
echo -e "${YELLOW}Agent logs (last 30 lines):${NC}"
sudo journalctl -u k3s-agent --no-pager -n 30

echo ""
echo -e "${GREEN}=== RESET COMPLETE ===${NC}"
echo ""
echo "The K3s agent should now be properly configured."
echo "Check if the node appears on the Scaleway server:"
echo "  kubectl get nodes -o wide"
