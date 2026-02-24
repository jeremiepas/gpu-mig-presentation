#!/bin/bash

# Dynamic Kubernetes Cluster Deployment Script
# Handles variable environments and generates manifests with correct values

set -e

echo "🚀 Starting dynamic cluster deployment..."

# Load credentials
if [ -f "credentials.env" ]; then
    source credentials.env
    echo "✅ Loaded credentials from credentials.env"
else
    echo "❌ credentials.env not found. Please create it with SCW_ACCESS_KEY, SCW_SECRET_KEY, etc."
    exit 1
fi

# Default environment
env="${1:-dev}"

echo "📋 Environment: $env"

# Check if Terraform needs to be applied
if ! terraform -chdir=terraform/environments/$env output -raw instance_dns 2>/dev/null; then
    echo "❌ Terraform outputs not available. Running terraform apply first..."
    terraform -chdir=terraform/environments/$env apply -auto-approve
fi

# Get Terraform outputs
instance_dns=$(terraform -chdir=terraform/environments/$env output -raw instance_dns)
instance_ip=$(terraform -chdir=terraform/environments/$env output -raw instance_ip)

echo "🌐 Instance DNS: $instance_dns"
echo "📡 Instance IP: $instance_ip"

echo "🌐 Instance DNS: $instance_dns"
echo "📡 Instance IP: $instance_ip"

# Create generated directory
mkdir -p k8s/generated

echo "📝 Generating dynamic manifests..."

# Generate Ingress with dynamic host
cat > k8s/generated/ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: $instance_dns
    http:
      paths:
      - path: /grafana
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
      - path: /prometheus
        pathType: Prefix
        backend:
          service:
            name: prometheus
            port:
              number: 9090
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
EOF

# Generate Grafana config with correct URL
sed "s|dda6040a-6b4a-46f1-bafb-d8105f7ebc68.pub.instances.scw.cloud|$instance_dns|g" k8s/04-grafana.yaml > k8s/generated/grafana.yaml

echo "✅ Generated manifests in k8s/generated/"

# Wait for SSH to be available
echo "🔑 Waiting for SSH access..."
for i in {1..30}; do
    if ssh -i ssh_key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$instance_ip "echo 'SSH ready'" &>/dev/null; then
        echo "✅ SSH is ready"
        break
    fi
    echo "🕒 Waiting for SSH... attempt $i/30"
    sleep 5
 done

# Wait for K3s to be ready (or install it if not present)
echo "⏳ Checking K3s status..."
k3s_installed=false
for i in {1..5}; do
    if ssh -i ssh_key -o StrictHostKeyChecking=no ubuntu@$instance_ip "sudo systemctl is-active k3s" &>/dev/null; then
        echo "✅ K3s is already running"
        k3s_installed=true
        break
    fi
    echo "🕒 Checking K3s... attempt $i/5"
    sleep 2
done

# If K3s is not installed, install it manually
if [ "$k3s_installed" = false ]; then
    echo "📦 K3s not found, installing manually..."
    ssh -i ssh_key -o StrictHostKeyChecking=no ubuntu@$instance_ip << 'ENDSSH'
        echo "Installing K3s..."
        curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sudo sh -
        echo "Enabling and starting K3s service..."
        sudo systemctl enable k3s
        sudo systemctl start k3s
        echo "Waiting for K3s to be ready..."
        sleep 30
ENDSSH
fi

# Wait for K3s to be fully ready
echo "⏳ Waiting for K3s to be ready..."
for i in {1..20}; do
    if ssh -i ssh_key -o StrictHostKeyChecking=no ubuntu@$instance_ip "sudo k3s kubectl get nodes" &>/dev/null; then
        echo "✅ K3s is ready"
        break
    fi
    echo "🕒 Waiting for K3s... attempt $i/20"
    sleep 5
 done

# Get kubeconfig
echo "📥 Retrieving kubeconfig..."
ssh -i ssh_key -o StrictHostKeyChecking=no ubuntu@$instance_ip "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config
sed -i "s|127.0.0.1|$instance_ip|g" ~/.kube/config
chmod 600 ~/.kube/config

echo "✅ Kubeconfig retrieved and configured"

# Deploy core components
echo "🚀 Deploying core components..."

kubectl apply -f k8s/00-namespaces.yaml
kubectl apply -f k8s/01-gpu-operator.yaml
kubectl apply -f k8s/03-prometheus.yaml
kubectl apply -f k8s/generated/grafana.yaml
kubectl apply -f k8s/04-grafana-datasources.yaml

echo "✅ Core components deployed"

# Deploy GPU configuration (time slicing by default)
echo "🎛️  Configuring GPU setup..."
kubectl apply -f k8s/02-timeslicing-config.yaml

echo "✅ GPU configuration applied"

# Deploy demo workloads
echo "📦 Deploying demo workloads..."
kubectl apply -f k8s/05-moshi-setup.yaml
kubectl apply -f k8s/06-moshi-timeslicing.yaml

echo "✅ Demo workloads deployed"

# Deploy dynamic ingress
echo "🌉 Deploying ingress..."
kubectl apply -f k8s/generated/ingress.yaml

echo "✅ Ingress deployed"

# Wait for pods to be ready
echo "🕒 Waiting for pods to be ready..."
sleep 30

# Show final status
echo "📊 Final cluster status:"
kubectl get pods -A

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "🔗 Service URLs:"
echo "   Grafana:     http://$instance_dns/grafana"
echo "   Prometheus:  http://$instance_dns/prometheus"
echo "   Direct IP:   http://$instance_ip:30300 (Grafana)"
echo ""
echo "🔑 Grafana credentials: admin/admin"
echo ""
echo "📋 To switch GPU modes:"
echo "   Time Slicing: kubectl apply -f k8s/02-timeslicing-config.yaml"
echo "   MIG:          kubectl apply -f k8s/02-mig-config.yaml"
echo ""
echo "💡 Note: GPU features require a GPU instance type (L4-2G-24G)"
echo "   Current instance: DEV1-S (non-GPU, for testing only)"
