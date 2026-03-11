# AGENTS.md

Guidelines for AI coding agents working in this repository.

## Project Overview

Terraform + Kubernetes infrastructure for GPU MIG vs Time Slicing demos on Scaleway cloud. Provisions GPU instance (L4-24GB), deploys K3s, GPU operator, Prometheus, Grafana, and demo workloads.

## Environments

| Environment | Terraform Path | State Key | Usage |
|------------|----------------|-----------|-------|
| **dev** (default) | `terraform/environments/dev/` | `dev/terraform.tfstate` | Local development |
| **prod** | `terraform/environments/prod/` | `prod/terraform.tfstate` | CI/CD deployments |
| **local** | `terraform/environments/local/` | N/A | Local GPU machine |

State backend: S3 on Scaleway (`gpu-mig-presentation-tfstate` bucket).

### Quick Start

```bash
source credentials-local.env
make init && make validate && make deploy-scaleway

# Get instance IP and kubeconfig
terraform -chdir=terraform/environments/dev output instance_ip
ssh -i ~/.ssh/id_rsa ubuntu@<IP> "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config
sed -i 's|127.0.0.1|<IP>|g' ~/.kube/config
```

## Build/Lint/Test Commands

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make init` | Initialize Terraform (ENV=dev/prod/local) |
| `make validate` | Validate Terraform configuration |
| `make deploy-scaleway` | Deploy to Scaleway (ENV=dev by default) |
| `make deploy-local` | Deploy to local GPU machine |
| `make destroy` | Destroy Scaleway deployment |
| `make clean` | Clean local state files |
| `make switch-timeslicing` | Switch GPU to Time Slicing mode |
| `make switch-mig` | Switch GPU to MIG mode |
| `make status` | Check pod status |

Env vars: `ENV=dev|prod|local`, `MODE=timeslicing|mig`

### Terraform Commands

```bash
terraform -chdir=terraform/environments/dev init
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/dev plan -out=tfplan
terraform -chdir=terraform/environments/dev apply -auto-approve tfplan
terraform -chdir=terraform/environments/dev destroy
terraform fmt -recursive
```

### Kubernetes YAML Validation

```bash
# Validate all YAML files
for f in $(find k8s -name "*.yaml"); do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" || exit 1
done

# Validate single file
python3 -c "import yaml; yaml.safe_load(open('k8s/<file>.yaml'))"

# Dry-run kubectl
kubectl apply -f k8s/<file>.yaml --dry-run=client -o yaml
```

### Kubectl Apply Order

```bash
kubectl apply -f k8s/00-namespaces.yaml
kubectl apply -f k8s/01-gpu-operator.yaml
kubectl apply -f k8s/02-timeslicing-config.yaml  # or 02-mig-config.yaml
kubectl apply -f k8s/03-prometheus.yaml
kubectl apply -f k8s/04-grafana.yaml
kubectl apply -f k8s/05-moshi-setup.yaml
kubectl apply -f k8s/06-moshi-timeslicing.yaml  # or 07-moshi-mig.yaml
```

## Code Style Guidelines

### Terraform
- **Version**: >= 1.0 (1.7.0 in CI), **Provider**: Scaleway ~> 2.40
- **Naming**: snake_case, include `description`, `type`, `default`
- **Formatting**: 2-space indent, align equals, `terraform fmt -recursive`

### Kubernetes YAML
- **Naming**: Numbered prefixes (00-, 01-...), kebab-case for resources
- **Style**: 2-space indent, `---` for documents, `app` label, explicit namespace, resource limits

### General
2-space indent, lines <100 chars, minimal comments, never commit secrets.

## Naming Conventions

| Context | Convention | Example |
|---------|------------|---------|
| Terraform resources | snake_case | `instance_type` |
| Kubernetes resources | kebab-case | `migstrategy-config` |
| K8s manifest files | number-prefix | `02-mig-config.yaml` |

## Project Structure

| Path | Description |
|------|-------------|
| `.github/workflows/` | CI/CD (deploy.yml, destroy.yml, validate.yml) |
| `terraform/environments/{dev,prod,local}/` | Environment configs |
| `k8s/` | Kubernetes manifests (00-07) |
| `argo-app/` | ArgoCD definitions |
| `shell.nix` | Nix dev shell |

## Common Tasks

```bash
# Add new K8s manifest: create k8s/08-*.yaml, validate, kubectl apply

# Modify Terraform: edit .tf, terraform fmt && validate, plan, apply

# Switch GPU mode
kubectl apply -f k8s/02-timeslicing-config.yaml  # Time Slicing
kubectl apply -f k8s/02-mig-config.yaml          # MIG

# Cleanup after destroy
rm -f terraform/environments/dev/terraform.tfstate*
rm -rf terraform/environments/dev/.terraform
```

## Error Handling

| Issue | Solution |
|-------|----------|
| Terraform errors | Check `terraform plan` output |
| K8s pod issues | `kubectl describe pod <name>`, `kubectl logs <name>` |
| CI failures | Check GitHub Actions logs |
| State lock | `terraform force-unlock <LOCK_ID>` |

## CI/CD

| Workflow | Trigger | Description |
|----------|---------|-------------|
| validate.yml | PR | terraform init/validate/plan + YAML check |
| deploy.yml | manual | terraform apply + kubectl apply |
| destroy.yml | manual | terraform destroy |

**GitHub Secrets**: `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `SSH_PRIVATE_KEY` (Base64), `K3S_KUBECONFIG` (Base64)

**Local**: `credentials-local.env` (git-ignored)

## Project-Specific Details

| Item | Value |
|------|-------|
| GPU | NVIDIA L4-24GB (Scaleway H100-1-80G) |
| MIG profiles | `mig.1g.6gb`, `mig.2g.12gb`, `mig.3g.24gb` |
| Time slicing | 4 GPU replicas by default |
| Services | Grafana (30300), Prometheus (30090), K3s API (6443) |
| Credentials | Grafana: admin/admin |
| Cost | ~€0.85/hour |