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

export x``="$KUBECONFIG_LOCAL"

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
    traefik.ingress.kubernetes.io/router.middlewares: monitoring-strip-prefix@kubernetescrd
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
      - path: /billing-api
        pathType: Prefix
        backend:
          service:
            name: billing-api
            port:
              number: 80
      - path: /billing-metrics
        pathType: Prefix
        backend:
          service:
            name: scaleway-billing-exporter
            port:
              number: 9091
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
kubectl apply -f ../k8s/10-scaleway-dashboard.yaml

echo "✅ Core components deployed"

# Deploy Scaleway billing API components
echo "💰 Deploying Scaleway billing API..."

# Check if scaleway-credentials secret exists, create if not
if ! kubectl get secret scaleway-credentials -n monitoring &> /dev/null; then
  echo "📝 Creating scaleway-credentials secret (empty - populate manually)..."
  kubectl create secret generic scaleway-credentials \
    --namespace=monitoring \
    --from-literal=access-key="" \
    --from-literal=secret-key="" \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "⚠️  Warning: Secret created with empty values. Update with: kubectl set secret ..."
fi

# Apply billing API manifests
kubectl apply -f ../k8s/11-billing-api.yaml
kubectl apply -f ../k8s/08-scaleway-billing.yaml

# Wait for billing API to be ready
echo "⏳ Waiting for billing API to start..."
kubectl wait --for=condition=available --timeout=60s deployment/billing-api -n monitoring 2>/dev/null || true
kubectl wait --for=condition=available --timeout=60s deployment/scaleway-billing-exporter -n monitoring 2>/dev/null || true

echo "✅ Billing API components deployed"

# Generate billing dashboard ConfigMap
echo "📊 Creating billing dashboard..."
cat > k8s/generated/billing-dashboard.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: billing-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  billing-dashboard.json: |
    {
      "dashboard": {
        "title": "Scaleway Billing Dashboard",
        "uid": "scaleway-billing",
        "version": 1,
        "refresh": "5m",
        "timezone": "browser",
        "time": { "from": "now-30d", "to": "now" },
        "panels": [
          {
            "id": 1,
            "title": "Total Monthly Cost",
            "type": "stat",
            "gridPos": { "h": 4, "w": 6, "x": 0, "y": 0 },
            "targets": [
              {
                "expr": "scaleway_monthly_cost_total",
                "legendFormat": "Total EUR",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "currency EUR",
                "thresholds": {
                  "steps": [
                    { "value": 0, "color": "green" },
                    { "value": 100, "color": "yellow" },
                    { "value": 500, "color": "red" }
                  ]
                }
              }
            }
          },
          {
            "id": 2,
            "title": "L4 Hourly Cost",
            "type": "stat",
            "gridPos": { "h": 4, "w": 6, "x": 6, "y": 0 },
            "targets": [
              {
                "expr": "scaleway_l4_hourly_cost",
                "legendFormat": "€/hour",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "currency EUR",
                "thresholds": {
                  "steps": [
                    { "value": 0, "color": "green" }
                  ]
                }
              }
            }
          },
          {
            "id": 3,
            "title": "Daily Cost Projection",
            "type": "stat",
            "gridPos": { "h": 4, "w": 6, "x": 12, "y": 0 },
            "targets": [
              {
                "expr": "scaleway_daily_cost_projection",
                "legendFormat": "€/day",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "currency EUR",
                "thresholds": {
                  "steps": [
                    { "value": 0, "color": "green" },
                    { "value": 20, "color": "yellow" },
                    { "value": 50, "color": "red" }
                  ]
                }
              }
            }
          },
          {
            "id": 4,
            "title": "Monthly Cost Projection",
            "type": "stat",
            "gridPos": { "h": 4, "w": 6, "x": 18, "y": 0 },
            "targets": [
              {
                "expr": "scaleway_monthly_cost_projection",
                "legendFormat": "€/month",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "currency EUR",
                "thresholds": {
                  "steps": [
                    { "value": 0, "color": "green" },
                    { "value": 500, "color": "yellow" },
                    { "value": 1000, "color": "red" }
                  ]
                }
              }
            }
          },
          {
            "id": 5,
            "title": "L4 Minutes Used",
            "type": "graph",
            "gridPos": { "h": 8, "w": 12, "x": 0, "y": 4 },
            "targets": [
              {
                "expr": "scaleway_l4_minutes_used",
                "legendFormat": "Minutes",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "m"
              }
            }
          },
          {
            "id": 6,
            "title": "Instance Type",
            "type": "stat",
            "gridPos": { "h": 4, "w": 12, "x": 12, "y": 4 },
            "targets": [
              {
                "expr": "scaleway_instance_type",
                "legendFormat": "{{type}}",
                "refId": "A"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "none"
              }
            }
          }
        ],
        "templating": {
          "list": []
        },
        "timepicker": {}
      }
    }
EOF

kubectl apply -f k8s/generated/billing-dashboard.yaml
echo "✅ Billing dashboard deployed"

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
echo "   Grafana:          http://$instance_dns/grafana"
echo "   Prometheus:       http://$instance_dns/prometheus"
echo "   Billing API:      http://$instance_dns/billing-api"
echo "   Billing Metrics:  http://$instance_dns/billing-metrics"
echo "   Direct IP:        http://$instance_ip:30300 (Grafana)"
echo ""
echo "📊 Dashboards:"
echo "   Infrastructure:  Scaleway Infrastructure (Grafana)"
echo "   Billing:         Scaleway Billing (Grafana)"
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
echo "🔐 Billing API requires Scaleway credentials:"
echo "   kubectl set secret -n monitoring scaleway-credentials --from-literal=access-key=YOUR_KEY --from-literal=secret-key=YOUR_SECRET"
echo ""
echo "🔗 To add a K3s agent from another machine, run:"
echo "   curl -sfL https://get.k3s.io | K3S_URL=https://$instance_ip:6443 K3S_TOKEN=<TOKEN> sh -"
