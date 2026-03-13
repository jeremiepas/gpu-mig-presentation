# Homelab ArgoCD Applications

This directory contains ArgoCD Application manifests for the homelab environment, deploying all Kubernetes resources from both `nixos/` and `k8s/common/` directories.

## Application Structure

### 1. **common-infrastructure** (k8s/common/)
Deploys base infrastructure components shared across all environments:
- Namespaces
- NVIDIA runtime class
- GPU operator base configuration
- Base monitoring components

**Path**: `k8s/common/`  
**Namespace**: `default`  
**Sync**: Automated (prune + self-heal)

### 2. **nixos-base-infrastructure** (nixos/)
Deploys NixOS-specific base infrastructure:
- `00-namespaces.yaml` - Core namespaces
- `01_runtimeClass.yaml` - Container runtime configuration
- `02_demonSet_gpu.yaml` - GPU DaemonSet
- `03_node.yaml` - Node configuration

**Path**: `nixos/`  
**Namespace**: `default`  
**Sync**: Automated (prune + self-heal)

### 3. **monitoring-stack** (nixos/k8s/generated/)
Deploys monitoring dashboards and Grafana configuration:
- Grafana deployment and configuration
- Billing dashboard
- Custom dashboards

**Path**: `nixos/k8s/generated/`  
**Namespace**: `monitoring`  
**Sync**: Automated (prune + self-heal)

### 4. **observability-platform** (Multi-source)
Comprehensive monitoring platform combining:
- **From k8s/common/**:
  - Prometheus
  - Grafana base
  - Node Exporter
  - Kube State Metrics
  - DCGM Exporter (GPU metrics)
- **From nixos/k8s/generated/**:
  - Grafana dashboards
  - Billing dashboard

**Namespace**: `monitoring`  
**Sync**: Automated (prune + self-heal)  
**Sync Wave**: 2 (deploys after base infrastructure)

### 5. **homelab-specific** (k8s/environments/homelab/)
Homelab-specific configurations:
- GPU time-slicing configuration (2 replicas)
- Local storage class
- Ingress with `.montech.mylab` domains
- Reduced resource requests

**Path**: `k8s/environments/homelab/`  
**Namespace**: `default`  
**Sync**: Automated (prune + self-heal)

### 6. **moshi-application** (nixos/kube-moshi-webui/)
Moshi WebUI and GPU workload application:
- Moshi WebUI deployment
- GPU workload configurations

**Path**: `nixos/kube-moshi-webui/`  
**Namespace**: `moshi-demo`  
**Sync**: Automated (prune + self-heal)

### 7. **ingress-configuration** (nixos/k8s/generated/)
Ingress controller configuration:
- Ingress rules for all services
- Domain routing

**Path**: `nixos/k8s/generated/ingress.yaml`  
**Namespace**: `default`  
**Sync**: Automated (prune + self-heal)

## Deployment Order

Applications are deployed in the following order using sync waves:

1. **Wave 0** (default): Base infrastructure
   - common-infrastructure
   - nixos-base-infrastructure
   - homelab-specific

2. **Wave 1**: Networking
   - ingress-configuration

3. **Wave 2**: Monitoring
   - observability-platform
   - monitoring-stack

4. **Wave 3**: Applications
   - moshi-application

## Access Points

After deployment, services are available at:

| Service | URL | Credentials |
|---------|-----|-------------|
| **ArgoCD** | https://argocd.montech.mylab | admin / (see secret) |
| **Grafana** | https://grafana.montech.mylab | admin / admin |
| **Prometheus** | https://prometheus.montech.mylab | N/A |
| **Moshi WebUI** | https://moshi.montech.mylab | N/A |

## Management Commands

### Deploy All Applications
```bash
kubectl apply -f k8s/argocd/environments/homelab/
```

### Check Application Status
```bash
argocd app list -l environment=homelab
argocd app get common-infrastructure
argocd app get observability-platform
```

### Sync Specific Application
```bash
argocd app sync common-infrastructure
argocd app sync observability-platform --prune
```

### View Application Logs
```bash
kubectl logs -n argocd deployment/argocd-application-controller -f
```

### Troubleshooting

#### Application Out of Sync
```bash
argocd app diff <app-name>
argocd app sync <app-name> --force
```

#### Check Application Health
```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

#### View Sync Status
```bash
argocd app get <app-name> --show-operation
```

## AppProject

All homelab applications belong to the `homelab` AppProject with:
- Source: `https://github.com/jeremie-lesage/gentle-circuit.git`
- Destinations: All namespaces in local cluster
- RBAC roles: `homelab-admin`, `homelab-viewer`

## Monitoring & Observability

The observability platform provides:

### Metrics Collection
- **Prometheus**: Scrapes metrics from all services
- **Node Exporter**: Node-level metrics
- **Kube State Metrics**: Kubernetes object metrics
- **DCGM Exporter**: GPU metrics (utilization, memory, temperature)

### Visualization
- **Grafana**: Pre-configured dashboards
- **Billing Dashboard**: Cost tracking and resource usage
- **GPU Dashboard**: GPU utilization and performance

### Dashboards Available
1. Kubernetes Cluster Overview
2. Node Metrics
3. GPU Utilization (DCGM)
4. Billing and Cost Analysis
5. Application Performance

## Notes

- All applications use automated sync with prune and self-heal enabled
- Resources are tracked using ArgoCD finalizers for proper cleanup
- Ignore differences configured for dynamic fields (replicas, clusterIP)
- Health checks configured for Deployments
- Retry logic with exponential backoff (5s → 10s → 20s → 40s → 3m)
