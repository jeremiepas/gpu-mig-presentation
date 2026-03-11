---
description: Deploy ArgoCD to the montech homelab K3s cluster
agent: build
# model: ollama/rnj-1:8b-cloud
---

```bash
export KUBECONFIG=/home/jeremie/Documents/perso/gpu-mig-presentation/k3s-config.yaml
```


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
