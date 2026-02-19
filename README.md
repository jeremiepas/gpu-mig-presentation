# GPU MIG Presentation Infrastructure

Terraform + Kubernetes infrastructure for GPU MIG vs Time Slicing presentation demo.

## Prerequisites

- GitHub account with repo creation rights
- Scaleway account with API keys
- Terraform >= 1.0

## Setup

### 1. Create GitHub Repository

```bash
# Option 1: Using GitHub CLI (if available)
gh repo create gpu-mig-presentation --private --clone

# Option 2: Manually
# 1. Go to https://github.com/new
# 2. Create private repo: gpu-mig-presentation
# 3. Clone this folder to your local machine
# 4. Push to GitHub:
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USER/gpu-mig-presentation.git
git push -u origin main
```

### 2. Configure GitHub Secrets

Go to Settings > Secrets and variables > Actions:

| Secret | Description | Example |
|--------|-------------|---------|
| `SCW_ACCESS_KEY` | Scaleway access key | `SCW...` |
| `SCW_SECRET_KEY` | Scaleway secret key | `xxxxx...` |
| `SCW_PROJECT_ID` | Scaleway project ID | `xxxxx-xxxx-...` |
| `K3S_KUBECONFIG` | K3s kubeconfig content | (see below) |

To get K3s kubeconfig (after first deploy):
```bash
cat /etc/rancher/k3s/k3s.yaml | base64 -w0
```

### 3. Deploy Infrastructure

**Automatic (GitHub Actions):**
- Push to main branch triggers deploy
- Or manually: Actions > Deploy Infrastructure > Run workflow

**Manual:**
```bash
cd terraform
terraform init
terraform apply
```

## Usage

### Demo Flow (25 minutes)

1. **Context (3min)**: Explain GPU cost increase, need for sharing
2. **Time Slicing Demo (8min)**:
   - Show 3 pods running with time-slicing
   - Demonstrate resource contention
   - Show memory isolation issues
3. **MIG Demo (10min)**:
   - Switch to MIG mode
   - Show isolated MIG instances
   - Crash one pod - show others unaffected
4. **Grafana Comparison (2min)**:
   - Dashboard showing before/after metrics
5. **Wrap-up (2min)**:
   - Key takeaways

### Access Services

| Service | URL | Default Creds |
|---------|-----|---------------|
| Grafana | `http://<IP>:30300` | admin/admin |
| Prometheus | `http://<IP>:30090` | - |
| K3s API | `https://<IP>:6443` | via kubeconfig |

### Commands

```bash
# Check GPU nodes
kubectl get nodes -o wide
kubectl describe node <node> | grep -A5 nvidia

# List GPU pods
kubectl get pods -n moshi-demo -o wide

# View GPU allocation
kubectl get nodes -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}'

# Switch between Time Slicing and MIG
kubectl apply -f k8s/02-timeslicing-config.yaml  # Time Slicing
kubectl apply -f k8s/02-mig-config.yaml          # MIG
```

## Cost

- **L4-2G-24G**: ~€0.85/hour
- **Presentation (30min setup + 25min demo)**: ~€0.78

## Cleanup

**Option 1: GitHub Actions**
- Go to Actions > Destroy Infrastructure > Run workflow
- Type "destroy" in confirmation

**Option 2: Manual**
```bash
cd terraform
terraform destroy
```

## Files

```
.
├── .github/workflows/
│   ├── deploy.yml      # Auto-deploy on main push
│   ├── destroy.yml    # Manual destroy
│   └── validate.yml   # PR validation
├── terraform/
│   ├── main.tf        # Provider config
│   ├── variables.tf   # Variables
│   ├── outputs.tf     # Outputs
│   ├── instances.tf   # GPU instance
│   └── cloud-init.yaml.tpl  # K3s setup
├── k8s/
│   ├── 00-namespaces.yaml
│   ├── 01-gpu-operator.yaml
│   ├── 02-mig-config.yaml
│   ├── 02-timeslicing-config.yaml
│   ├── 03-prometheus.yaml
│   ├── 04-grafana.yaml
│   ├── 05-moshi-setup.yaml
│   ├── 06-moshi-timeslicing.yaml
│   └── 07-moshi-mig.yaml
└── README.md
```

## MIG Instances on L4-24GB

| MIG Profile | Memory | Use Case |
|-------------|--------|----------|
| `mig.1g.6gb` | 6GB | Small workloads |
| `mig.2g.12gb` | 12GB | Medium workloads |
| `mig.3g.24gb` | 24GB | Full GPU |

## Notes

- L4 supports MIG - perfect for isolation demos
- Time slicing shows contention issues (crash affects all)
- MIG shows true isolation (crash doesn't affect others)
- Grafana dashboard compares metrics between modes
