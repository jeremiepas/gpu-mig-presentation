#!/bin/bash

# Generate dynamic Kubernetes manifests using Terraform outputs
# Usage: ./generate-manifests.sh [env]

set -e

env="${1:-dev}"

# Get Terraform outputs
instance_dns=$(terraform -chdir=terraform/environments/$env output -raw instance_dns)
instance_ip=$(terraform -chdir=terraform/environments/$env output -raw instance_ip)

echo "Generating manifests for environment: $env"
echo "Instance DNS: $instance_dns"
echo "Instance IP: $instance_ip"

# Create generated directory
mkdir -p k8s/generated

# Generate Ingress manifest
cat > k8s/generated/ingress.yaml <<EOF
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
echo "Generating Grafana configuration..."
sed "s|dda6040a-6b4a-46f1-bafb-d8105f7ebc68.pub.instances.scw.cloud|$instance_dns|g" k8s/04-grafana.yaml > k8s/generated/grafana.yaml

# Generate monitoring ingress
cat > k8s/generated/monitoring-ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
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
EOF

echo "✅ Manifests generated successfully in k8s/generated/"
echo "Apply them with: kubectl apply -f k8s/generated/"
