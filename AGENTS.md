# AGENTS.md

Guidelines for AI coding agents working in this repository.

## Project Overview

Terraform + Kubernetes infrastructure for GPU MIG vs Time Slicing demos on Scaleway cloud. Provisions GPU instance (L4-24GB), deploys K3s, GPU operator, Prometheus, Grafana, and demo workloads.

## Environments

This project supports two environments. Both use the same credentials (`source credentials.env`), the difference is only the terraform environment path.

| Environment | Terraform Path | State Backend | Usage |
|-------------|----------------|---------------|-------|
| **dev** (default) | `terraform/environments/dev/` | S3 on Scaleway | Local development, manual deployments |
| **prod** | `terraform/environments/prod/` | S3 on Scaleway | CI/CD via GitHub Actions |

### Dev Environment (Default)

```bash
# Load credentials (same for both environments)
source credentials.env

# Terraform commands with -chdir
# Note: No -backend=false needed - dev uses S3 backend by default
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev plan -out=tfplan
terraform -chdir=terraform/environments/dev apply -auto-approve tfplan
terraform -chdir=terraform/environments/dev destroy

# Get instance IP
terraform -chdir=terraform/environments/dev output instance_ip

# SSH to instance (uses ~/.ssh/id_rsa)
ssh -i ~/.ssh/id_rsa ubuntu@<INSTANCE_IP>

# Get kubeconfig from remote
ssh -i ~/.ssh/id_rsa ubuntu@<INSTANCE_IP> "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config
sed -i 's|127.0.0.1|<INSTANCE_IP>|g' ~/.kube/config

# Deploy K8s manifests
kubectl apply -f k8s/00-namespaces.yaml
kubectl apply -f k8s/04-grafana.yaml
```

### Prod Environment

Deployed via GitHub Actions (push to `main` branch):

```bash
# Terraform with prod environment
terraform -chdir=terraform/environments/prod init
terraform -chdir=terraform/environments/prod plan -out=tfplan
terraform -chdir=terraform/environments/prod apply -auto-approve tfplan
```

State is stored in S3 backend (`s3.fr-par.scw.cloud`).

## State Management

### Dev Environment
- **State**: S3 backend
- **Bucket**: `gpu-mig-presentation-tfstate`
- **Key**: `dev/terraform.tfstate`
- **Persistence**: Shared via S3, persists across runs
- **Use case**: Local development and testing

### Prod Environment
- **State**: S3 backend
- **Bucket**: `gpu-mig-presentation-tfstate`
- **Key**: `prod/terraform.tfstate`
- **Persistence**: Shared via S3, persists across runs
- **Use case**: Production deployments via CI/CD

## Cleanup Commands

```bash
# After terraform destroy, clean up local state files
rm -f terraform/environments/dev/terraform.tfstate* terraform/environments/dev/.terraform.lock.hcl

# Clean terraform cache
rm -rf terraform/environments/dev/.terraform
```

## GitHub CI/CD Setup

### Required Secrets
Set these in GitHub repository settings:
- `SCW_ACCESS_KEY` - Scaleway access key
- `SCW_SECRET_KEY` - Scaleway secret key
- `SCW_PROJECT_ID` - Scaleway project ID
- `SSH_PRIVATE_KEY` - Base64-encoded SSH private key for instance access

### Workflow Triggers
- **Dev**: Manual only via `workflow_dispatch`
- **Prod**: Manual only via `workflow_dispatch` with environment selection
- **Destroy**: Manual only with confirmation

### Deployment Process
1. Push code changes to any branch
2. Manually trigger `Deploy Infrastructure` workflow
3. Select environment (dev/prod)
4. Workflow runs terraform and kubernetes deployment
5. For prod, state is stored in S3 for persistence

## Build/Lint/Test Commands

## Build/Lint/Test Commands

### Terraform

```bash
terraform -chdir=terraform/environments/dev init  # Initialize with S3 backend (dev)
terraform -chdir=terraform/environments/dev validate              # Validate configuration
terraform -chdir=terraform/environments/dev plan -out=tfplan      # Plan changes
terraform -chdir=terraform/environments/dev apply -auto-approve tfplan  # Apply changes
terraform -chdir=terraform/environments/dev destroy               # Destroy infrastructure
terraform fmt -recursive        # Format files
```

### Kubernetes YAML Validation

```bash
# Validate all YAML files
for f in $(find k8s -name "*.yaml"); do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" || exit 1
done

# Validate single file
python3 -c "import yaml; yaml.safe_load(open('k8s/<filename>.yaml'))"
```

### Kubectl Commands

```bash
kubectl apply -f k8s/00-namespaces.yaml
kubectl apply -f k8s/01-gpu-operator.yaml
kubectl apply -f k8s/02-timeslicing-config.yaml  # or 02-mig-config.yaml
kubectl apply -f k8s/03-prometheus.yaml
kubectl apply -f k8s/04-grafana.yaml
kubectl apply -f k8s/05-moshi-setup.yaml
kubectl apply -f k8s/06-moshi-timeslicing.yaml  # or 07-moshi-mig.yaml
kubectl get nodes -o wide
kubectl get pods -n moshi-demo -o wide
```

### Development Environment

```bash
nix-shell  # Tools: gh, scaleway-cli, k9s, kubectl, jq, fzf
```

## Code Style Guidelines

### Terraform

- **Version**: >= 1.0 (1.7.0 in CI)
- **Provider**: Scaleway ~> 2.40
- **Files**: main.tf (provider/backend), variables.tf, outputs.tf, instances.tf, bucket.tf
- **Naming**: snake_case for resources/variables, include `description`, `type`, `default`
- **Formatting**: 2-space indent, align equals signs, run `terraform fmt -recursive`
- **Backend**: S3 on Scaleway (s3.fr-par.scw.cloud)

### Kubernetes YAML

- **File Naming**: Numbered prefixes (00-, 01-, 02-...)
- **Organization**: 00-namespaces, 01-gpu-operator, 02-* (GPU config), 03-prometheus, 04-grafana, 05-07-moshi workloads
- **Style**: 2-space indent, `---` for documents, `app` label, explicit namespace, resource limits
- **Naming**: kebab-case (`migstrategy-config`), prefix ConfigMaps by purpose

### General

- 2-space indentation everywhere
- Lines under 100 characters
- Minimal comments, self-documenting names
- Never commit secrets

## Naming Conventions

| Context | Convention | Example |
|---------|------------|---------|
| Terraform | snake_case | `instance_type` |
| Kubernetes | kebab-case | `migstrategy-config` |
| K8s files | number-prefix | `02-mig-config.yaml` |

## Project Structure

- `.github/workflows/` - CI/CD (deploy.yml, destroy.yml, validate.yml)
- `terraform/` - IaC files
- `k8s/` - Kubernetes manifests (numbered 00-07)
- `argo-app/` - ArgoCD definitions
- `shell.nix` - Nix dev shell

## CI/CD

- **validate.yml** (PR): terraform init/validate/plan + YAML check
- **deploy.yml** (main push): terraform apply + kubectl apply
- **destroy.yml** (manual): terraform destroy

## Common Tasks

```bash
# Add new K8s manifest
# 1. Create file in k8s/ with number prefix (e.g., 08-*.yaml)
# 2. Validate: python3 -c "import yaml; yaml.safe_load(open('k8s/<file>'))"
# 3. Add to deploy.yml workflow if needed

# Modify Terraform
# 1. Edit appropriate .tf file
# 2. Run: terraform fmt -recursive && terraform validate
# 3. Review: terraform plan
# 4. Apply: terraform apply

# Switch GPU mode
kubectl apply -f k8s/02-timeslicing-config.yaml  # Time Slicing
kubectl apply -f k8s/02-mig-config.yaml          # MIG
```

## Error Handling

- Terraform: Check `terraform plan` output before applying
- K8s: Use `kubectl describe` and `kubectl logs` for debugging
- CI failures: Check GitHub Actions logs for detailed error messages

## Development Workflow

1. Make changes to Terraform or K8s files
2. Run validation commands (terraform validate, YAML check)
3. Test locally if possible (terraform plan, kubectl apply --dry-run)
4. Push changes and wait for CI validation
5. Merge to main triggers deployment

**Environment Usage:**
- **dev** (default): Use for local development, testing, and manual deployments. Run terraform commands directly with `source credentials.env`. State is stored in S3 backend
- **prod**: Use for production via GitHub Actions. State is stored in S3 backend. Triggered by push to `main` branch

## Project-Specific Details

- GPU: NVIDIA L4-24GB (Scaleway H100-1-80G instance type)
- MIG profiles on L4: `mig.1g.6gb`, `mig.2g.12gb`, `mig.3g.24gb`
- Time slicing: 4 GPU replicas by default (configurable)
- Services: Grafana (port 30300), Prometheus (port 30090), K3s API (port 6443)
- Default credentials: Grafana admin/admin
- Estimated cost: ~€0.85/hour for H100-1-80G instance

## Secrets Management

- GitHub Secrets required for CI/CD:
  - `SCW_ACCESS_KEY` - Scaleway access key
  - `SCW_SECRET_KEY` - Scaleway secret key
  - `SCW_PROJECT_ID` - Scaleway project ID
  - `K3S_KUBECONFIG` - Base64-encoded kubeconfig (after first deploy)
- Local secrets in `credentials.env` (git-ignored)
