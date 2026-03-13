#!/bin/bash
# K3s Installation Script
# Environment: ${k3s_version}
# Version: ${environment}

set -e

echo "Installing K3s ${k3s_version} for environment: ${environment}"

# Install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${k3s_version} sh -s - \
  --write-kubeconfig-mode 644

# Enable and start K3s service
sudo systemctl enable k3s
sudo systemctl start k3s

# Wait for K3s to be ready
timeout 300 bash -c 'until sudo k3s kubectl get nodes | grep -q Ready; do sleep 5; done'

echo "K3s installation complete for ${environment}"
