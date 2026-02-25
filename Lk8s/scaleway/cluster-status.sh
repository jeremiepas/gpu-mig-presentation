#!/bin/bash
# K3s Cluster Management Script for Scaleway
# Run this on the Scaleway K3s server
#
# This script helps manage the K3s cluster and monitor connected agents

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Must run as root${NC}"
  exit 1
fi

echo -e "${BLUE}=== K3s Cluster Management (Scaleway) ===${NC}"
echo ""

# Check if K3s is running
if ! systemctl is-active --quiet k3s; then
  echo -e "${RED}Error: K3s is not running${NC}"
  echo "Start it with: sudo systemctl start k3s"
  exit 1
fi

# Get K3s node info
echo -e "${YELLOW}=== K3s Cluster Information ===${NC}"
echo ""

# Get nodes
echo "Nodes in cluster:"
kubectl get nodes -o wide 2>/dev/null || echo "Cannot get nodes - kubectl not configured"

echo ""

# Get K3s version
echo "K3s version:"
kubectl version --client 2>/dev/null || echo "kubectl not available"

echo ""

# Get agent token
echo "K3s Agent Token (for joining new nodes):"
K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/agent-token 2>/dev/null || echo "not found")
if [ "$K3S_TOKEN" != "not found" ]; then
  echo "${K3S_TOKEN:0:30}... (truncated)"
else
  echo "$K3S_TOKEN"
fi

echo ""

# Tailscale info (if installed)
if command -v tailscale &> /dev/null; then
  echo -e "${YELLOW}=== Tailscale Status ===${NC}"
  echo ""
  
  TAILSCALE_STATUS=$(tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "unknown")
  echo "Status: $TAILSCALE_STATUS"
  
  if [ "$TAILSCALE_STATUS" == "Running" ]; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "not assigned")
    TAILSCALE_HOSTNAME=$(tailscale status --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo "unknown")
    
    echo "Tailscale IP: $TAILSCALE_IP"
    echo "Hostname: $TAILSCALE_HOSTNAME"
    echo ""
    echo "Connected peers:"
    tailscale status 2>/dev/null | grep -v "^Self" | head -20
  else
    echo "Tailscale is not running"
    echo "Run ./setup-tailscale.sh to configure"
  fi
else
  echo -e "${YELLOW}Tailscale not installed${NC}"
fi

echo ""

# Quick commands
echo -e "${YELLOW}=== Quick Commands ===${NC}"
echo ""
echo "Get agent token:"
echo "  sudo cat /var/lib/rancher/k3s/server/agent-token"
echo ""
echo "Check K3s logs:"
echo "  sudo journalctl -u k3s -f"
echo ""
echo "Get kubeconfig:"
echo "  sudo cat /etc/rancher/k3s/k3s.yaml"
echo ""
echo "Restart K3s:"
echo "  sudo systemctl restart k3s"
echo ""
echo "View pods:"
echo "  kubectl get pods -A -o wide"
