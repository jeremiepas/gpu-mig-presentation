#!/bin/bash
# K3s Installation
set -e

echo "=== Step 5: Installing K3s ==="

export DEBIAN_FRONTEND=noninteractive

# Install K3s (lightweight Kubernetes)
echo "Installing K3s..."

# Download and install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

# Enable K3s service
systemctl enable k3s

# Configure K3s to use Docker as runtime
mkdir -p /etc/systemd/system/k3s.service.d
cat > /etc/systemd/system/k3s.service.d/docker.conf << 'EOF'
[Service]
ExecStartPost=/usr/local/bin/flag_docker.sh
EOF

# Create flag script to configure Docker as runtime
cat > /usr/local/bin/flag_docker.sh << 'EOF'
#!/bin/bash
# Wait for K3s to be ready
sleep 5

# Configure K3s to use Docker runtime
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    echo "K3s installed successfully"
fi
EOF

chmod +x /usr/local/bin/flag_docker.sh

# Configure K3s with GPU support and custom settings
cat > /etc/systemd/system/k3s.service.env << 'EOF'
K3S_KUBECONFIG_MODE="644"
K3S_ENABLE_SERVING_SKIPS=true
K3S_DISABLE="traefik,servicelb"
K3S_ARGS="--docker --write-kubeconfig-mode 644"
EOF

# Create kubeconfig directory
mkdir -p /root/.kube
ln -sf /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config

# Install kubectl
curl -fsSL "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# Install kubectl bash completion
kubectl completion bash > /etc/bash_completion.d/kubectl

# Install helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install kubectx/kubens
git clone https://github.com/ahmetb/kubectx /opt/kubectx
ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
ln -sf /opt/kubectx/kubens /usr/local/bin/kubens

# Install k9s (terminal UI for Kubernetes)
curl -fsSL https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz -o /tmp/k9s.tar.gz
tar -xzf /tmp/k9s.tar.gz -C /usr/local/bin/
rm /tmp/k9s.tar.gz

# Install kind (Kubernetes in Docker)
curl -fsSL https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 -o /usr/local/bin/kind
chmod +x /usr/local/bin/kind

# Install minikube
curl -fsSL https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 -o /usr/local/bin/minikube
chmod +x /usr/local/bin/minikube

# Install skaffold
curl -fsSL https://github.com/GoogleContainerTools/skaffold/releases/download/v2.9.0/skaffold-linux-amd64 -o /usr/local/bin/skaffold
chmod +x /usr/local/bin/skaffold

# Install kustomize
curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash -s -- 5.0.3 /usr/local/bin/kustomize

# Install flux CLI (GitOps)
curl -fsSL https://fluxcd.io/install.sh | bash

# Install ArgoCD CLI
curl -fsSL https://argoproj.github.io/argo-workflows/ci-install.sh | bash

# Pre-load some common Kubernetes manifests
mkdir -p /root/manifests

# Create namespace manifests
cat > /root/manifests/00-namespaces.yaml << 'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-gpu-operator
---
apiVersion: v1
kind: Namespace
metadata:
  name: moshi-demo
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
EOF

# Start K3s (optional - will start on boot via systemd)
# systemctl start k3s || echo "K3s will start on first boot"

echo "=== K3s installed ==="
echo "To start K3s: systemctl start k3s"
echo "To get kubeconfig: cat /etc/rancher/k3s/k3s.yaml"
