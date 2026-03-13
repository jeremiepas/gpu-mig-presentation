# ArgoCD Deployment Plan

## Overview

| Aspect | Details |
|--------|---------|
| **Project** | GPU MIG Presentation with ArgoCD GitOps |
| **Target** | NixOS K3s and Standard K8s clusters |
| **Access URL** | `https://<domain>/argocd` |
| **Secret Management** | Infisical (optional) |
| **ArgoCD Version** | v2.10.0 |

This deployment plan covers the installation and configuration of ArgoCD for managing GPU workloads across two Kubernetes environments: a NixOS-based K3s cluster and a standard Kubernetes cluster on Scaleway.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Git Repository                          │
│                    (gpu-mig-presentation)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ArgoCD Instances                            │
│  ┌───────────────────────┐    ┌──────────────────────────────┐  │
│  │   NixOS K3s ArgoCD     │    │    Standard K8s ArgoCD       │  │
│  │   /argocd              │    │    /argocd                   │  │
│  └───────────────────────┘    └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Managed Workloads                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐         │
│  │ GPU      │ │Monitoring│ │ Moshi    │ │ Ingress  │         │
│  │ Operator │ │ Stack    │ │ Workloads│ │ Routes   │         │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

- **Two ArgoCD instances**: One for NixOS K3s, one for standard K8s
- **Path-based ingress routing**: `/argocd` for both instances
- **GitOps workflow**: Declarative management of GPU workloads
- **Application-based organization**: Logical grouping of related resources

---

## Phase 1: NixOS K3s Deployment

### 1. Prerequisites

Before deploying ArgoCD on NixOS K3s, ensure the following:

- [ ] K3s cluster is running and accessible
- [ ] `kubectl` configured with appropriate kubeconfig
- [ ] Traefik ingress controller is deployed
- [ ] NodePort access available (ports 30080, 30443)
- [ ] Git repository accessible from the cluster
- [ ] (Optional) Infisical credentials for secret management

**Verify Prerequisites**:

```bash
# Check cluster access
export KUBECONFIG="$HOME/.kube/config-k3s-remote"
kubectl get nodes

# Verify Traefik is running
kubectl get pods -n kube-system | grep traefik

# Check node connectivity
kubectl get nodes -o wide
```

### 2. Deploy ArgoCD Namespace

Create the `argocd` namespace and service account:

```bash
kubectl apply -f nixos/argocd/00-namespace.yaml
```

**File: `nixos/argocd/00-namespace.yaml`**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/part-of: gitops
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-application-controller
  namespace: argocd
```

### 3. Install ArgoCD Core Components

Deploy ArgoCD server, repo-server, application controller, and Redis:

```bash
kubectl apply -f nixos/argocd/01-argocd-install.yaml
```

**Key Configurations**:

| Component | Configuration |
|-----------|--------------|
| Server | `--insecure` mode, `--basehref /argocd` |
| Service Type | NodePort (ports 30080, 30443) |
| Resource Tracking | Annotation-based |

**Wait for Deployment**:

```bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
kubectl wait --for=condition=available deployment/argocd-repo-server -n argocd --timeout=120s
kubectl wait --for=condition=available deployment/argocd-application-controller -n argocd --timeout=120s
```

### 4. Configure Ingress with /argocd Path

Configure Traefik ingress for path-based routing:

```bash
kubectl apply -f nixos/argocd/02-ingress.yaml
```

**Ingress Configuration**:

- Path: `/argocd`
- PathType: Prefix
- Middleware: Custom headers for X-Forwarded-Proto
- TLS: Optional cert-manager integration

**Verify Ingress**:

```bash
kubectl get ingress -n argocd
kubectl describe ingress argocd-server -n argocd
```

### 5. Setup Infisical Integration (Optional)

If using Infisical for secret management:

**Prerequisites**:

```bash
# Install External Secrets Operator
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/v0.9.0/deploy/crds/bundle.yaml
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/v0.9.0/deploy/bundle.yaml

# Verify operator is running
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets --timeout=120s
```

**Deploy Infisical Configuration**:

```bash
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"
envsubst < nixos/argocd/04-infisical-secrets.yaml | kubectl apply -f -
```

### 6. Create Application Definitions

Deploy ArgoCD Applications to manage GPU workloads:

```bash
kubectl apply -f nixos/argocd/03-applications.yaml
```

**Applications Created**:

| Application | Path | Namespace | Purpose |
|-------------|------|-----------|---------|
| namespaces | `k8s/00-namespaces.yaml` | default | Create all namespaces |
| nvidia-runtimeclass | `k8s/00-nvidia-runtimeclass.yaml` | gpu-operator | GPU runtime class |
| gpu-operator | `k8s/01-gpu-operator.yaml` | gpu-operator | NVIDIA device plugin |
| gpu-config | `k8s/02-timeslicing-config.yaml` | gpu-operator | GPU configuration |
| monitoring-stack | `k8s/` (selected files) | monitoring | Prometheus + Grafana |
| moshi-setup | `k8s/05-moshi-setup.yaml` | moshi-demo | Moshi demo setup |
| moshi-inference-timeslicing | `k8s/06-moshi-timeslicing.yaml` | moshi-demo | Time slicing workloads |
| moshi-inference-mig | `k8s/07-moshi-mig.yaml` | moshi-demo | MIG workloads |
| ingress-routes | `k8s/08-ingress-routes.yaml` | monitoring | Ingress routes |
| billing-exporter | `k8s/08-scaleway-billing.yaml` | monitoring | Billing metrics |

### 7. Verify Deployment

**Check Pods**:

```bash
kubectl get pods -n argocd
```

**Expected Output**:

```
NAME                                              READY   STATUS    RESTARTS   AGE
argocd-application-controller-xxx                  1/1     Running   0          2m
argocd-redis-xxx                                 1/1     Running   0          2m
argocd-repo-server-xxx                           1/1     Running   0          2m
argocd-server-xxx                                1/1     Running   0          2m
```

**Verify Applications**:

```bash
# Port forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Or access via ingress
# URL: https://<domain>/argocd
```

---

## Phase 2: Standard K8s Deployment

### 1. Prerequisites

- [ ] Kubernetes cluster is running (Scaleway or other)
- [ ] `kubectl` configured with appropriate kubeconfig
- [ ] Ingress controller available (Traefik, NGINX, etc.)
- [ ] LoadBalancer support configured
- [ ] Git repository accessible from the cluster

**Verify Prerequisites**:

```bash
# Check cluster access
export KUBECONFIG="$HOME/.kube/config"
kubectl get nodes

# Verify ingress controller
kubectl get pods -n kube-system | grep -E "traefik|nginx"
```

### 2. Deploy ArgoCD Namespace

```bash
kubectl apply -f k8s/argocd/00-namespace.yaml
```

### 3. Install ArgoCD Core Components

Deploy with LoadBalancer service type for Scaleway:

```bash
kubectl apply -f k8s/argocd/01-argocd-install.yaml
```

**Key Differences from NixOS**:

- Service Type: LoadBalancer (instead of NodePort)
- Scaleway annotations for load balancer configuration
- Updated URL configuration

**Wait for LoadBalancer**:

```bash
# Get LoadBalancer IP
kubectl get svc argocd-server -n argocd

# Wait for external IP
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

### 4. Configure Ingress with /argocd Path

```bash
kubectl apply -f k8s/argocd/02-ingress.yaml
```

**Scaleway-Specific Configuration**:

```yaml
metadata:
  annotations:
    service.beta.kubernetes.io/scw-loadbalancer-type: "lb-s"
    service.beta.kubernetes.io/scw-loadbalancer-zone: "fr-par-1"
```

### 5. Create Application Definitions

```bash
kubectl apply -f k8s/argocd/03-applications.yaml
```

Applications mirror the NixOS K3s setup but target the standard K8s cluster.

### 6. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n argocd

# Verify LoadBalancer service
kubectl get svc argocd-server -n argocd

# Check ingress
kubectl get ingress -n argocd
```

---

## Applications Managed

### Application Overview

| Cluster | Application | Sync Policy | Auto-Prune | Self-Heal |
|---------|-------------|-------------|------------|-----------|
| NixOS K3s | namespaces | Automated | Yes | Yes |
| NixOS K3s | nvidia-runtimeclass | Automated | Yes | Yes |
| NixOS K3s | gpu-operator | Automated | Yes | Yes |
| NixOS K3s | gpu-config | Automated | Yes | Yes |
| NixOS K3s | monitoring-stack | Automated | Yes | Yes |
| NixOS K3s | moshi-setup | Automated | Yes | Yes |
| NixOS K3s | moshi-inference-timeslicing | Automated | Yes | Yes |
| NixOS K3s | moshi-inference-mig | Automated | Yes | Yes |
| NixOS K3s | ingress-routes | Automated | Yes | Yes |
| NixOS K3s | billing-exporter | Automated | Yes | Yes |
| Standard K8s | All Applications | Automated | Yes | Yes |

### Application Dependencies

```
namespaces
    │
    ▼
nvidia-runtimeclass
    │
    ▼
gpu-operator ───► gpu-config (MIG or Time Slicing)
    │
    ▼
monitoring-stack
    │
    ▼
moshi-setup
    │
    ├──► moshi-inference-timeslicing
    └──► moshi-inference-mig
    │
    ▼
ingress-routes
    │
    ▼
billing-exporter
```

---

## Security Considerations

### Default Credentials

**Initial Login**:

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | Retrieved from secret (see below) |

**Retrieve Initial Password**:

```bash
# NixOS K3s
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Standard K8s
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Infisical Integration

If using Infisical for secret management:

- External Secrets Operator syncs secrets from Infisical
- ArgoCD admin password managed externally
- Git repository credentials securely stored
- Automatic secret rotation support

### Ingress TLS Configuration

**Cert-Manager Integration**:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - <domain>
      secretName: argocd-tls-secret
```

### RBAC Policies

**Default Policy** (read-only for unauthenticated):

```yaml
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, *, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    g, admin, role:admin
```

**Recommendations**:

1. Change default admin password immediately
2. Configure SSO/OAuth integration
3. Enable audit logging
4. Restrict repository access
5. Use fine-grained RBAC for team members

---

## Access Instructions

### UI Access

**NixOS K3s**:

```
URL: https://<domain>/argocd
Example: https://montech.montech.mylab/argocd
```

**Standard K8s**:

```
URL: https://<domain>/argocd
Example: https://4edcb867-7b4e-4890-b3d6-7912075f20d8.pub.instances.scw.cloud/argocd
```

**Login Steps**:

1. Navigate to the ArgoCD URL
2. Enter username: `admin`
3. Enter password (retrieved from secret)
4. Click "Login"

### CLI Access

**Install ArgoCD CLI**:

```bash
# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# macOS
curl -sSL -o argocd-darwin-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
sudo install -m 555 argocd-darwin-amd64 /usr/local/bin/argocd
```

**Login to ArgoCD**:

```bash
# NixOS K3s
argocd login montech.montech.mylab:80 --insecure --grpc-web-root-path /argocd

# Standard K8s
argocd login <domain>:443 --grpc-web-root-path /argocd
```

**Common CLI Commands**:

```bash
# List applications
argocd app list

# Get application status
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# View application diff
argocd app diff <app-name>

# Sync all applications
argocd app sync -l app.kubernetes.io/part-of=gpu-mig-demo
```

### Initial Password Retrieval

**Method 1: Direct Secret Access**:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

**Method 2: Using ArgoCD CLI**:

```bash
argocd admin initial-password -n argocd
```

**Method 3: Patch for Plain Text**:

```bash
kubectl -n argocd patch secret argocd-initial-admin-secret -p '{"stringData":{"password":"<new-password>"}}'
```

---

## File Structure

```
.
├── nixos/
│   └── argocd/
│       ├── 00-namespace.yaml              # ArgoCD namespace
│       ├── 01-argocd-install.yaml         # Core ArgoCD components
│       ├── 02-ingress.yaml                # Traefik ingress
│       ├── 03-applications.yaml           # Application definitions
│       └── 04-infisical-secrets.yaml      # External secrets (optional)
├── k8s/
│   └── argocd/
│       ├── 00-namespace.yaml              # ArgoCD namespace
│       ├── 01-argocd-install.yaml         # Core ArgoCD components
│       ├── 02-ingress.yaml                # Ingress configuration
│       ├── 03-applications.yaml           # Application definitions
│       └── 04-infisical-secrets.yaml      # External secrets (optional)
└── docs/
    └── PLAN.md                            # This document
```

---

## Troubleshooting

### ArgoCD Server Not Accessible

```bash
# Check pod status
kubectl get pods -n argocd

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# Check ingress
kubectl describe ingress -n argocd

# Verify Traefik/ingress controller
kubectl get pods -n kube-system | grep traefik
```

### Applications Not Syncing

```bash
# Check application status
argocd app list

# View application events
argocd app get <app-name> --show-operation

# Check resource health
kubectl get applications -n argocd -o yaml
```

### Infisical Integration Issues

```bash
# Check External Secrets Operator
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets

# Verify ClusterSecretStore
kubectl get clustersecretstore

# Check ExternalSecret status
kubectl get externalsecrets -n argocd
```

---

## Next Steps

After successful deployment:

1. **Change Admin Password**: Update default credentials
2. **Configure Git Webhooks**: Enable automatic sync on commits
3. **Set up Notifications**: Configure Slack/Email for sync events
4. **Define RBAC Policies**: Create team-specific permissions
5. **Enable Monitoring**: Add ArgoCD to Prometheus/Grafana
6. **Configure Backup**: Backup ArgoCD configuration and application state
7. **Document Workflows**: Create team playbooks for common operations

---

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Ingress Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)
- [External Secrets Operator](https://external-secrets.io/)
- [Infisical Documentation](https://infisical.com/docs)
- [Traefik Ingress Documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-ingress/)
- [K3s Documentation](https://docs.k3s.io/)
