#!/bin/bash
# Tailscale Server Setup Script for Scaleway K3s
# Run this on the Scaleway K3s server
#
# This script:
#   1. Installs Tailscale on the K3s server
#   2. Starts Tailscale in server mode
#   3. Generates auth key for client nodes
#   4. Saves configuration for client nodes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Tailscale Server Setup for Scaleway K3s ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Must run as root${NC}"
  echo "Usage: sudo $0 [TAILSCALE_AUTH_KEY]"
  exit 1
fi

TAILSCALE_AUTH_KEY="${1:-}"

# Detect OS
if [ ! -f /etc/os-release ]; then
  echo -e "${RED}Error: Cannot detect OS${NC}"
  exit 1
fi

. /etc/os-release
echo "Detected OS: $PRETTY_NAME"

# Install Tailscale
echo ""
echo -e "${YELLOW}Installing Tailscale...${NC}"

if command -v tailscale &> /dev/null; then
  echo "Tailscale is already installed"
  TAILSCALE_VERSION=$(tailscale --version)
  echo "Version: $TAILSCALE_VERSION"
else
  # Install based on OS
  case "$ID" in
    ubuntu|debian)
      curl -fsSL https://tailscale.com/install.sh | sh
      ;;
    fedora|rhel|centos)
      curl -fsSL https://tailscale.com/install.sh | sh
      ;;
    *)
      echo -e "${RED}Unsupported OS: $ID${NC}"
      exit 1
      ;;
  esac
fi

# Start Tailscale
echo ""
echo -e "${YELLOW}Starting Tailscale...${NC}"

if [ -n "$TAILSCALE_AUTH_KEY" ]; then
  echo "Using provided auth key"
  tailscale up --operator=root --advertise-exit-node --accept-routes --authkey="$TAILSCALE_AUTH_KEY"
else
  echo "No auth key provided - will use interactive login"
  echo "To use auth key, run: sudo $0 <YOUR_AUTH_KEY>"
  echo ""
  echo "Get your auth key from: https://login.tailscale.com/admin/settings/keys"
  echo ""
  read -p "Press Enter to continue with interactive login..."
  tailscale up --operator=root
fi

# Wait for Tailscale to connect
echo ""
echo -e "${YELLOW}Waiting for Tailscale to connect...${NC}"
sleep 3

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
TAILSCALE_HOSTNAME=$(tailscale status --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}Tailscale Status:${NC}"
echo "  Hostname: $TAILSCALE_HOSTNAME"
echo "  Tailscale IP: $TAILSCALE_IP"

# Get K3s agent token
echo ""
echo -e "${YELLOW}Getting K3s agent token...${NC}"
K3S_AGENT_TOKEN=$(cat /var/lib/rancher/k3s/server/agent-token 2>/dev/null || echo "")
if [ -z "$K3S_AGENT_TOKEN" ]; then
  echo -e "${RED}Error: Cannot find K3s agent token${NC}"
  echo "Make sure K3s is installed and running"
  exit 1
fi
echo "Agent token: ${K3S_AGENT_TOKEN:0:20}..."

# Save configuration for client nodes
CONFIG_FILE="/root/lk8s-config.txt"

echo ""
echo -e "${YELLOW}Saving configuration to $CONFIG_FILE${NC}"

cat > "$CONFIG_FILE" << EOF
# Lk8s Configuration for Client Nodes
# Copy this to your local machine

## Tailscale Server Info
TAILSCALE_IP=$TAILSCALE_IP
TAILSCALE_HOSTNAME=$TAILSCALE_HOSTNAME

## K3s Cluster Info
K3S_SERVER_IP=$TAILSCALE_IP
K3S_AGENT_TOKEN=$K3S_AGENT_TOKEN

## Instructions for local machine:
# 1. Set up Tailscale on your local NixOS machine (see ../local/nixos-tailscale.nix)
# 2. Run: sudo tailscale up
# 3. Wait for Tailscale to connect
# 4. Run: ./join-k3s-agent.sh $TAILSCALE_IP '$K3S_AGENT_TOKEN' nixos-gpu
EOF

chmod 600 "$CONFIG_FILE"

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Tailscale is now running on your Scaleway K3s server."
echo ""
echo "Next steps:"
echo "1. Set up Tailscale on your local NixOS machine"
echo "2. Copy the config from: $CONFIG_FILE"
echo "3. Run the join script on your local machine"
echo ""
echo "To check Tailscale status:"
echo "  sudo tailscale status"
echo ""
echo "To get the agent token:"
echo "  sudo cat /var/lib/rancher/k3s/server/agent-token"
