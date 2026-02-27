#!/bin/bash

# Dynamic Kubernetes Cluster Deployment Script
# Handles variable environments and generates manifests with correct values

set -e

REMOTE_HOST="100.120.26.64"
REMOTE_USER="jeremie"
SSH_KEY="$HOME/.ssh/id_rsa"
KUBECONFIG_LOCAL="$HOME/.kube/config-k3s-remote"

instance_ip=$REMOTE_HOST
instance_dns="montech.tail21c10a.ts.net"

export KUBECONFIG="$KUBECONFIG_LOCAL"

echo "🚀 Starting dynamic cluster deployment..."


echo "📡 Instance IP: $instance_ip"
echo "🌐 Instance DNS: $instance_dns"

mkdir -p k8s/generated


kubectl cluster-info || exit 1


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
sed "s|8ba06232-7938-40f5-a5ff-a5ad1f37a7e2.pub.instances.scw.cloud|$instance_dns|g" ../k8s/04-grafana.yaml > k8s/generated/grafana.yaml

echo "✅ Generated manifests in k8s/generated/"

# Deploy core components
echo "🚀 Deploying core components..."

kubectl apply -f ../k8s/00-namespaces.yaml
kubectl apply -f ../k8s/01-gpu-operator.yaml
kubectl apply -f ../k8s/03-prometheus.yaml
kubectl apply -f k8s/generated/grafana.yaml
kubectl apply -f ../k8s/04-grafana-datasources.yaml

echo "✅ Core components deployed"

# Deploy GPU configuration (time slicing by default)
echo "🎛️  Configuring GPU setup..."

kubectl apply -f ./01_runtimeClass.yaml
kubectl apply -f ./02_demonSet_gpu.yaml
kubectl apply -f ./03_node.yaml
kubectl apply -f ./04_create_gpu_pod.yaml

echo "✅ check Configuring GPU setup"

kubectl apply -f ./05_test_pod.yaml

echo "✅ GPU configuration applied"

# Deploy demo workloads
echo "📦 Deploying demo workloads..."

kubectl apply -f ../k8s/05-moshi-setup.yaml
kubectl apply -f ../k8s/06-moshi-timeslicing.yaml


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

# Install and configure Tailscale
echo "🔧 Installing Tailscale..."

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
echo "💡 Note: GPU features require a GPU instance type (H100-1-80G)"
echo "   Current instance: DEV1-S (non-GPU, for testing only)"
echo ""
echo "🔗 To add a K3s agent from another machine, run:"
echo "   curl -sfL https://get.k3s.io | K3S_URL=https://$instance_ip:6443 K3S_TOKEN=<TOKEN> sh -"
