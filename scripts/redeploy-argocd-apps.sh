#!/bin/bash
# Script to remove all existing ArgoCD applications and deploy new structure
# This script reorganizes ArgoCD to deploy all nixos/ and k8s/common/ manifests

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-k3s-remote}"
export KUBECONFIG

echo "=== ArgoCD Application Redeployment ==="
echo "Using kubeconfig: ${KUBECONFIG}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo "❌ kubectl not found. Please install kubectl."
  exit 1
fi

# Check if argocd CLI is available
if ! command -v argocd &> /dev/null; then
  echo "⚠️  argocd CLI not found. Install with: brew install argocd"
  echo "   Continuing with kubectl only..."
  ARGOCD_CLI=false
else
  ARGOCD_CLI=true
fi

# Check cluster connectivity
echo "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
  echo "❌ Cannot connect to Kubernetes cluster"
  echo "   Please check your kubeconfig: ${KUBECONFIG}"
  exit 1
fi
echo "✓ Connected to cluster"
echo ""

# Step 1: List existing applications
echo "=== Step 1: Listing Existing Applications ==="
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status 2>/dev/null || echo "No applications found"
echo ""

# Step 2: Confirm deletion
read -p "Do you want to remove ALL existing ArgoCD applications? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted by user"
  exit 0
fi

# Step 3: Delete all applications
echo ""
echo "=== Step 2: Removing Existing Applications ==="
apps=$(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$apps" ]; then
  echo "No applications to remove"
else
  for app in $apps; do
    echo "  - Deleting application: $app"
    kubectl delete application "$app" -n argocd --wait=false 2>/dev/null || echo "    Failed to delete $app"
  done
  
  echo ""
  echo "Waiting for applications to be removed..."
  sleep 5
  
  # Force delete any stuck applications
  remaining=$(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
  if [ -n "$remaining" ]; then
    echo "Force removing stuck applications..."
    for app in $remaining; do
      kubectl patch application "$app" -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
      kubectl delete application "$app" -n argocd --force --grace-period=0 2>/dev/null || true
    done
  fi
fi

echo "✓ All applications removed"
echo ""

# Step 4: Apply new AppProject
echo "=== Step 3: Creating Homelab AppProject ==="
kubectl apply -f k8s/argocd/common/05-homelab-appproject.yaml
echo "✓ AppProject created"
echo ""

# Step 5: Deploy new applications
echo "=== Step 4: Deploying New Applications ==="
echo "Applying applications from k8s/argocd/environments/homelab/"
kubectl apply -f k8s/argocd/environments/homelab/applications.yaml
kubectl apply -f k8s/argocd/environments/homelab/monitoring-app.yaml
echo "✓ Applications deployed"
echo ""

# Step 6: Wait for applications to sync
echo "=== Step 5: Waiting for Applications to Sync ==="
echo "This may take a few minutes..."
sleep 10

# Check application status
echo ""
echo "Application Status:"
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

# Step 7: Summary
echo ""
echo "=== Deployment Summary ==="
echo ""
echo "Applications deployed:"
echo "  1. common-infrastructure      - Base infrastructure from k8s/common/"
echo "  2. nixos-base-infrastructure  - NixOS base manifests"
echo "  3. monitoring-stack           - Grafana and dashboards"
echo "  4. observability-platform     - Full monitoring (Prometheus, Grafana, exporters)"
echo "  5. homelab-specific           - Homelab configurations"
echo "  6. moshi-application          - Moshi WebUI"
echo "  7. ingress-configuration      - Ingress rules"
echo ""
echo "Access points:"
echo "  - ArgoCD:     https://argocd.montech.mylab"
echo "  - Grafana:    https://grafana.montech.mylab"
echo "  - Prometheus: https://prometheus.montech.mylab"
echo "  - Moshi:      https://moshi.montech.mylab"
echo ""
echo "Next steps:"
echo "  1. Check application sync status: argocd app list"
echo "  2. View application details: argocd app get <app-name>"
echo "  3. Access Grafana dashboards at https://grafana.montech.mylab"
echo ""
echo "✓ Redeployment complete!"
