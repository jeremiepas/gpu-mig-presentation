# ArgoCD Deployment for Standard Kubernetes

This directory contains ArgoCD deployment manifests for managing the GPU MIG vs Time Slicing demo workloads on a standard Kubernetes cluster.

## Overview

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. These manifests deploy ArgoCD on a standard Kubernetes cluster (not NixOS K3s) and configure it to manage the cluster's workloads from the main `k8s/` directory.

## Architecture

The ArgoCD installation includes:

- **Application Controller**: Main controller that manages application state
- **Repo Server**: Handles Git repository operations
- **Server**: Web UI and API server
- **Dex**: Optional SSO authentication server
- **Redis**: Cache for repository data

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Ingress controller installed (nginx or Traefik)
- 2+ GB RAM available for ArgoCD components

## Deployment

### 1. Deploy ArgoCD

Apply the manifests in order:

```bash
# Create namespace
kubectl apply -f k8s/argocd/00-namespace.yaml

# Install ArgoCD components
kubectl apply -f k8s/argocd/01-argocd-install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s

# Create ingress
kubectl apply -f k8s/argocd/02-ingress.yaml

# Create projects
kubectl apply -f k8s/argocd/04-argocd-appproject.yaml

# Create applications
kubectl apply -f k8s/argocd/03-applications.yaml
```

### 2. Quick Deploy (All at once)

```bash
kubectl apply -k k8s/argocd/
```

Or:

```bash
for f in k8s/argocd/*.yaml; do
  kubectl apply -f "$f"
done
```

## Accessing ArgoCD

### Web UI

Once deployed, access the ArgoCD UI at:

```
https://<your-cluster-domain>/argocd
```

The server is configured to run at the `/argocd` root path.

### NodePort Access (No Ingress)

If you don't have an ingress controller, access ArgoCD via NodePort:

```bash
# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Access UI
echo "ArgoCD UI: http://${NODE_IP}:30080/argocd"

# Forward port for local access
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

Then open: http://localhost:8080/argocd

## Authentication

### Default Admin Password

Get the initial admin password:

```bash
# Default password is "admin"
# To get from secret (if configured):
kubectl -n argocd get secret argocd-secret -o jsonpath="{.data.admin.password}" | base64 -d
echo

# Or if using the default from the manifest:
echo "admin"
```

### Login via CLI

Install ArgoCD CLI:

```bash
# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# macOS
brew install argocd
```

Login:

```bash
# Using NodePort (no ingress)
argocd login <NODE_IP>:30080 --insecure

# Using ingress
argocd login <your-cluster-domain> --grpc-web-root-path /argocd

# Example with specific domain
argocd login 4edcb867-7b4e-4890-b3d6-7912075f20d8.pub.instances.scw.cloud:30443 --insecure
```

When prompted:
- Username: `admin`
- Password: `admin` (or from secret)

### Change Admin Password

```bash
argocd account update-password
```

## Using ArgoCD to Manage the Cluster

### View Applications

Via CLI:
```bash
argocd app list
argocd app get <app-name>
argocd app sync <app-name>
```

Via Web UI:
- Navigate to https://<domain>/argocd
- Log in with admin credentials
- View applications in the dashboard

### Application Structure

The ArgoCD applications are organized into projects:

| Project | Applications | Description |
|---------|-------------|-------------|
| `default` | namespaces-and-runtimeclass, ingress-controller, ingress-routes | Core infrastructure |
| `gpu-demo` | gpu-operator, gpu-configurations, moshi-setup, moshi-timeslicing-workloads, moshi-mig-workloads, moshi-visualization | GPU demo workloads |
| `monitoring` | monitoring-stack, monitoring-dashboards, billing-services, monitoring-ingress | Observability stack |

### Sync Applications

```bash
# Sync all applications
argocd app sync -l app.kubernetes.io/part-of=argocd

# Sync specific application
argocd app sync monitoring-stack

# Sync project
argocd app sync -p gpu-demo
```

### Manual Sync via UI

1. Go to https://<domain>/argocd
2. Select application
3. Click "Sync"
4. Select resources to sync
5. Click "Synchronize"

## Application Configuration

Each Application resource defines:

- **Source**: Git repository and path to manifests
- **Destination**: Kubernetes cluster and namespace
- **Sync Policy**: Automated sync, prune, and self-heal settings
- **Project**: Organization grouping (default, gpu-demo, monitoring)

Example Application structure:

```yaml
spec:
  project: gpu-demo
  source:
    repoURL: https://github.com/jeremie-lesage/gentle-circuit.git
    targetRevision: HEAD
    path: k8s
    directory:
      include: "01-gpu-operator.yaml"
  destination:
    server: https://kubernetes.default.svc
    namespace: gpu-operator
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Ingress Configuration

### nginx-ingress

The ingress is configured with nginx-ingress annotations:

```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /
  nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

### Traefik

If using Traefik, the `IngressRoute` resource is also provided:

```bash
kubectl apply -f k8s/argocd/02-ingress.yaml
```

This includes the `stripPrefix` middleware to handle the `/argocd` path.

## Differences from NixOS K3s Version

| Aspect | Standard K8s | NixOS K3s |
|--------|-------------|-----------|
| Installation | Manual manifests | systemd services |
| Database | Embedded (default) | External or embedded |
| High Availability | Manual replica configuration | Configured via NixOS options |
| Ingress | Manual Ingress/IngressRoute | Configured via NixOS nginx module |
| TLS | Manual cert management | Automatic via NixOS ACME |
| Service Type | NodePort | ClusterIP with load balancer |
| Root Path | `/argocd` | Configurable |
| Resource Limits | Set in manifests | Configured via NixOS options |

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n argocd

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

### Cannot Access UI

```bash
# Check ingress
kubectl get ingress -n argocd

# Check service
kubectl get svc -n argocd

# Port forward for testing
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Then open http://localhost:8080/argocd
```

### Applications Not Syncing

```bash
# Check application status
argocd app list

# Get detailed status
argocd app get <app-name>

# Check controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Sync manually with verbose output
argocd app sync <app-name> --prune --verbose
```

### Login Issues

```bash
# Reset admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData":{"admin.password":"'$$(htpasswd -bnBC 10 "" your-new-password | tr -d ':\n' | base64)'"}}'

# Delete and recreate secret with new password
kubectl delete secret argocd-secret -n argocd
kubectl create secret generic argocd-secret -n argocd \
  --from-literal=admin.password=<base64-encoded-hash> \
  --from-literal=admin.passwordMtime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

## Cleanup

To remove ArgoCD:

```bash
# Delete applications first
kubectl delete -f k8s/argocd/03-applications.yaml

# Delete projects
kubectl delete -f k8s/argocd/04-argocd-appproject.yaml

# Delete ingress
kubectl delete -f k8s/argocd/02-ingress.yaml

# Delete ArgoCD components
kubectl delete -f k8s/argocd/01-argocd-install.yaml

# Delete namespace
kubectl delete -f k8s/argocd/00-namespace.yaml
```

Or:

```bash
kubectl delete namespace argocd
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD GitHub](https://github.com/argoproj/argo-cd)
- [GitOps Guide](https://www.gitops.tech/)
