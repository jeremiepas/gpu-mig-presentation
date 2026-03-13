# ArgoCD on NixOS K3s

This directory contains ArgoCD deployment manifests for managing the NixOS K3s cluster using GitOps principles.

## Overview

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. These manifests deploy ArgoCD on your NixOS K3s cluster and configure it to manage all workloads from this repository.

## Files

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Creates the `argocd` namespace |
| `01-argocd-install.yaml` | Deploys ArgoCD with NodePort service and resource limits |
| `02-ingress.yaml` | Configures Traefik ingress for accessing ArgoCD UI |
| `03-applications.yaml` | Defines ArgoCD Applications for managing cluster workloads |
| `04-infisical-integration.yaml` | External secrets integration with Infisical (optional) |

## Prerequisites

- K3s cluster running on NixOS
- `kubectl` configured with kubeconfig
- Traefik ingress controller (already deployed in the cluster)

## Deployment

### 1. Deploy ArgoCD

```bash
# Navigate to the argocd directory
cd nixos/argocd

# Create namespace and install ArgoCD
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-argocd-install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=argocd -n argocd --timeout=300s

# Verify deployment
kubectl get pods -n argocd
```

### 2. Configure Ingress

```bash
# Deploy ingress configuration
kubectl apply -f 02-ingress.yaml

# Verify ingress is created
kubectl get ingress -n argocd
```

### 3. Deploy ArgoCD Applications

```bash
# Create ArgoCD Applications to manage cluster workloads
kubectl apply -f 03-applications.yaml

# Verify applications are created
kubectl get applications -n argocd
```

### 4. Optional: Deploy Infisical Integration

```bash
# Only if Infisical is available
kubectl apply -f 04-infisical-integration.yaml
```

## Accessing ArgoCD

### Via Ingress (Recommended)

ArgoCD UI is accessible at:

```
https://montech.montech.mylab/argocd
```

### Via NodePort (Direct Access)

If ingress is not configured, access ArgoCD directly:

```bash
# Get node IP
kubectl get nodes -o wide

# Access via NodePort
# HTTP:  http://<NODE_IP>:30080/argocd
# HTTPS: https://<NODE_IP>:30443/argocd
```

### Port Forwarding (Local Access)

```bash
# Forward ArgoCD server port to localhost
kubectl port-forward svc/argocd-server 8080:80 -n argocd

# Access locally
open http://localhost:8080/argocd
```

## Getting the Initial Admin Password

### Via CLI

```bash
# Get the initial admin password
argocd admin initial-password -n argocd

# Or extract from secret
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Via Secret (Alternative)

```bash
# Get password from secret
kubectl get secret argocd-secret -n argocd -o jsonpath="{.data.admin.password}" | base64 -d && echo
```

**Note:** The initial password is only valid for 24 hours. Change it after first login.

## Login via CLI

### Install ArgoCD CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd

# Verify installation
argocd version
```

### Login

```bash
# Login to ArgoCD server
argocd login montech.montech.mylab:80 \
  --username admin \
  --password $(kubectl get secret argocd-secret -n argocd -o jsonpath="{.data.admin.password}" | base64 -d) \
  --insecure \
  --grpc-web-root-path /argocd

# Or if using port-forward
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure
```

## Using ArgoCD to Manage the Cluster

### View Applications

```bash
# List all applications
argocd app list

# Get application details
argocd app get core-infrastructure
argocd app get monitoring-stack
argocd app get moshi-demo
```

### Sync Applications

```bash
# Sync all applications
argocd app sync --all

# Sync specific application
argocd app sync core-infrastructure
argocd app sync monitoring-stack
argocd app sync moshi-demo
```

### Check Sync Status

```bash
# Watch sync status
argocd app wait core-infrastructure --health

# Check application health
kubectl get applications -n argocd -o wide
```

### Application Resources

The following ArgoCD Applications are created:

| Application | Path | Namespace | Description |
|------------|------|-----------|-------------|
| `core-infrastructure` | `nixos/` | Various | Core K3s infrastructure (namespaces, runtime classes) |
| `gpu-operator` | `nixos/` | `gpu-operator` | GPU device plugin and configuration |
| `monitoring-stack` | `k8s/` | `monitoring` | Prometheus and Grafana stack |
| `moshi-demo` | `k8s/` | `moshi-demo` | Moshi AI demo workloads |
| `ingress-controller` | `k8s/` | `ingress-nginx` | Ingress controller and routes |
| `gpu-test` | `nixos/` | `default` | GPU test and validation pod |

## Switching GPU Modes

ArgoCD Applications support different GPU configurations:

### Time Slicing (Default)

```bash
# Apply time slicing configuration
kubectl apply -f k8s/02-timeslicing-config.yaml

# Deploy time slicing workload
argocd app sync moshi-demo
```

### MIG Mode

```bash
# Apply MIG configuration
kubectl apply -f k8s/02-mig-config.yaml

# Deploy MIG workload (different application)
kubectl apply -f k8s/07-moshi-mig.yaml
```

## Troubleshooting

### ArgoCD Pods Not Starting

```bash
# Check pod status
kubectl get pods -n argocd -o wide

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# Check events
kubectl describe pods -n argocd
```

### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n argocd

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=100

# Verify middleware
kubectl get middleware -n argocd
```

### Login Issues

```bash
# Reset admin password
kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "admin"}}'

# Restart ArgoCD server
kubectl rollout restart deployment argocd-server -n argocd
```

### Applications Not Syncing

```bash
# Force sync
argocd app sync <app-name> --force

# Check application events
argocd app get <app-name> -o yaml

# Check ArgoCD application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

## Security Considerations

1. **Change Default Password**: Change the admin password immediately after first login
2. **Enable HTTPS**: Use TLS certificates for production deployments
3. **RBAC**: Configure proper RBAC for team access
4. **Secrets**: Use External Secrets or sealed secrets for sensitive data
5. **Network Policies**: Consider implementing network policies for ArgoCD namespace

## Updating ArgoCD

```bash
# Update ArgoCD images in the manifests
# Edit 01-argocd-install.yaml with new image tags

# Apply changes
kubectl apply -f 01-argocd-install.yaml

# Verify rollout
kubectl rollout status deployment/argocd-server -n argocd
```

## Uninstalling ArgoCD

```bash
# Delete applications first
kubectl delete applications --all -n argocd

# Delete ArgoCD resources
kubectl delete -f 01-argocd-install.yaml
kubectl delete -f 02-ingress.yaml
kubectl delete -f 03-applications.yaml

# Delete namespace
kubectl delete -f 00-namespace.yaml
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD GitHub](https://github.com/argoproj/argo-cd)
- [GitOps Guide](https://www.gitops.tech/)
- [K3s Documentation](https://docs.k3s.io/)
