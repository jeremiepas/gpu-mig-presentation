# AGENTS.md

Guidelines for AI coding agents working in this repository.

## Project Overview

Terraform + Kubernetes infrastructure for GPU MIG vs Time Slicing demos on Scaleway cloud. Provisions GPU instance (L4-24GB), deploys K3s, GPU operator, Prometheus, Grafana, and demo workloads.

## Build/Lint/Test Commands

### Terraform

```bash
terraform init -backend=false  # Initialize without backend
terraform validate              # Validate configuration
terraform plan -out=tfplan      # Plan changes
terraform apply -auto-approve tfplan  # Apply changes
terraform destroy               # Destroy infrastructure
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

## Project-Specific Details

- GPU: NVIDIA L4-24GB (Scaleway L4-2G-24G instance type)
- MIG profiles on L4: `mig.1g.6gb`, `mig.2g.12gb`, `mig.3g.24gb`
- Time slicing: 4 GPU replicas by default (configurable)
- Services: Grafana (port 30300), Prometheus (port 30090), K3s API (port 6443)
- Default credentials: Grafana admin/admin
- Estimated cost: ~€0.85/hour for L4-2G-24G instance

## Secrets Management

- GitHub Secrets required for CI/CD:
  - `SCW_ACCESS_KEY` - Scaleway access key
  - `SCW_SECRET_KEY` - Scaleway secret key
  - `SCW_PROJECT_ID` - Scaleway project ID
  - `K3S_KUBECONFIG` - Base64-encoded kubeconfig (after first deploy)
- Local secrets in `credentials.env` (git-ignored)