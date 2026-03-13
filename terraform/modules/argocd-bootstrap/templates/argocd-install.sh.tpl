#!/bin/bash
# ArgoCD Installation Script
# Environment: ${environment}
# Git Repository: ${git_repo_url}

set -e

echo "Installing ArgoCD for environment: ${environment}"

# Create ArgoCD namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
timeout 300 bash -c 'until kubectl get pods -n argocd | grep -q Running; do sleep 5; done'
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "ArgoCD installation complete for ${environment}"
echo "Git repository: ${git_repo_url}"
