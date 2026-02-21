---
name: terraform-scaleway
description: Manage Scaleway infrastructure with Terraform
license: MPL-2.0
compatibility: opencode
metadata:
  audience: developers
  workflow: infrastructure
---
## What I do
- Create and manage Scaleway resources (instances, buckets, kubernetes, etc.)
- Write Terraform configuration using the Scaleway provider
- Validate and apply Terraform changes

## Provider Configuration
The Scaleway provider uses these authentication methods (in order of precedence):
1. Environment variables: `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`
2. Shared credentials file: `~/.scw/credentials`
3. Project ID: `SCW_PROJECT_ID`

Provider source: `scaleway/scaleway`
Provider version: `~> 2.40`

## Common Resources

### Instances (VMs)
```hcl
resource "scaleway_instance_ip" "example" {
}

resource "scaleway_instance_server" "example" {
  type  = "L4-2G-24G"
  image = "ubuntu_jammy"
}
```

### S3 Buckets
```hcl
resource "scaleway_s3_bucket" "example" {
  name          = "my-bucket"
  region        = "fr-par"
}
```

### Kubernetes (K3s)
```hcl
resource "scaleway_k8s_cluster" "example" {
  name    = "my-cluster"
  version = "1.28.2"
  cni     = "cilium"
  private_network_enabled = true
}

resource "scaleway_k8s_pool" "example" {
  cluster_id = scaleway_k8s_cluster.example.id
  node_type = "k3s-m6s"
  size      = 3
}
```

## Commands

### Initialize and validate
```bash
terraform init -backend=false
terraform validate
terraform fmt -recursive
```

### Plan and apply
```bash
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

### Destroy
```bash
terraform destroy
```

## Best Practices
- Always run `terraform fmt -recursive` after editing
- Validate with `terraform validate` before committing
- Use `-backend=false` for init in CI to avoid state conflicts
- Store state remotely (S3 on Scaleway recommended for production)
- Never commit secrets - use environment variables or `.gitignore`
