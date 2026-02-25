#!/bin/bash
# =============================================================================
# K3s Kubernetes Installation
# =============================================================================
# Purpose: Install K3s lightweight Kubernetes for GPU workloads
# Configured for single-node with embedded etcd
# =============================================================================

set -e

echo "=== [4/8] K3s Kubernetes Installation ==="

export DEBIAN_FRONTEND=noninteractive

# K3s version to install
K3S_VERSION="v1.28.4+k3s2"

# Install K3s with GPU support
echo "Installing K3s ${K3S_VERSION}..."

# Download and install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION} sh -s - \
    --write-kubeconfig-mode 644 \
    --disable=traefik \
    --disable=servicelb \
    --disable=metrics-server \
    --disable=local-storage \
    --disable=network-policy \
    --flannel-backend=wireguard-native \
    --cluster-cidr=10.42.0.0/16 \
    --service-cidr=10.43.0.0/16 \
    --cluster-dns=10.43.0.10 \
    --kube-proxy-arg="proxy-mode=ipvs" \
    --kubelet-arg="feature-gates=DevicePlugins=true" \
    --kubelet-arg="provider-id=scw://{{ .InstanceID }}" || {
    echo "Warning: K3s installation had issues, attempting to continue..."
}

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 10

# Configure K3s for GPU workloads
echo "Configuring K3s for GPU workloads..."

# Create K3s GPU configuration directory
mkdir -p /var/lib/rancher/k3s/server/manifests

# Create GPU device plugin manifest
cat > /var/lib/rancher/k3s/server/manifests/nvidia-device-plugin.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: nvidia-device-plugin
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: nvidia-device-plugin
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: nvidia-device-plugin-ds
    spec:
      tolerations:
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
      containers:
      - image: nvcr.io/nvidia/k8s-device-plugin:v0.14.5
        name: nvidia-device-plugin-ctr
        args:
          - "--config-file=/config/config.yaml"
        volumeMounts:
          - name: config
            mountPath: /config
      volumes:
        - name: config
          configMap:
            name: nvidia-device-plugin-config
      priorityClassName: system-node-critical
EOF

# Create NVIDIA device plugin configmap
cat > /tmp/nvidia-configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nvidia-device-plugin-config
  namespace: nvidia-device-plugin
data:
  config.yaml: |
    version: v1
    sharing:
      timeSlicing:
        resources:
          - name: nvidia.com/gpu
            replicas: 4
EOF

# Apply configmap if kubectl is available
if command -v kubectl &>/dev/null; then
    kubectl apply -f /tmp/nvidia-configmap.yaml || true
fi

# Configure K3s to use NVIDIA runtime
echo "Configuring K3s to use NVIDIA container runtime..."

# Create nvidia runtime config for containerd
mkdir -p /var/lib/rancher/k3s/agent/etc/containerd/
cat > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl << 'EOF'
[plugins.opt]
  path = "/var/lib/rancher/k3s/agent/containerd"

[plugins.cri]
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"

[plugins.cri.containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runtime.v1.linux"
  pod_sandbox_image = "rancher/mirrored-pause:3.9"

[plugins.cri.containerd.runtimes.nvidia.options]
  BinaryName = "/usr/bin/nvidia-container-runtime"
  RuntimeRootDir = "/run/nvidia/containerd"

[plugins.cri.containerd.runtimes.containerd]
  runtime_type = "io.containerd.runtime.v1.linux"
  pod_sandbox_image = "rancher/mirrored-pause:3.9"
EOF

# Restart K3s to apply changes
echo "Restarting K3s to apply changes..."
systemctl restart k3s || true

# Wait for K3s to be ready
sleep 15

# Verify K3s installation
echo "Verifying K3s installation..."
if command -v k3s &>/dev/null; then
    k3s --version
    echo "K3s: OK"
    
    # Get node status
    k3s kubectl get nodes 2>/dev/null || echo "K3s not yet ready"
    k3s kubectl get pods -A 2>/dev/null || echo "K3s not yet ready"
else
    echo "Warning: K3s command not found"
fi

# Install kubectl locally for debugging
echo "Installing kubectl for local debugging..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

# Create kubectl alias
echo "alias k='kubectl'" >> /root/.bashrc

# Create K3s management scripts
cat > /usr/local/bin/k3s-status.sh << 'SCRIPT'
#!/bin/bash
# K3s Status Check Script

echo "=== K3s Status ==="
systemctl status k3s --no-pager || echo "K3s service not found"

echo ""
echo "=== K3s Nodes ==="
kubectl get nodes -o wide 2>/dev/null || echo "K3s not ready"

echo ""
echo "=== K3s Pods ==="
kubectl get pods -A -o wide 2>/dev/null || echo "K3s not ready"
SCRIPT
chmod +x /usr/local/bin/k3s-status.sh

# Create K3s restart script
cat > /usr/local/bin/k3s-restart.sh << 'SCRIPT'
#!/bin/bash
# K3s Restart Script

echo "Restarting K3s..."
systemctl restart k3s
sleep 10
echo "K3s restarted"
SCRIPT
chmod +x /usr/local/bin/k3s-restart.sh

echo "=== K3s Installation Complete ==="
