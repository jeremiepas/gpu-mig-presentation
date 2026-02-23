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
  ip_id = scaleway_instance_ip.example.id
}
```

### Instance with SSH Keys (Cloud-init)
**IMPORTANT**: Use `user-data` key (not `cloud-init`) for cloud-init to work properly.

**Recommended**: Use both IAM SSH key + cloud-init together:
- IAM SSH key (`scaleway_iam_ssh_key`) - for Scaleway project management
- Cloud-init - for instance-level configuration (SSH keys, runcmd, etc.)

```hcl
# Create IAM SSH key
resource "scaleway_iam_ssh_key" "dev_key" {
  name       = "dev-key"
  public_key = file("${path.module}/ssh_key.pub")
  project_id = var.project_id
}

# Create instance with cloud-init
resource "scaleway_instance_server" "example" {
  name  = "my-instance"
  type  = "DEV1-S"
  image = "ubuntu_jammy"
  ip_id = scaleway_instance_ip.example.id

  user_data = {
    "user-data" = templatefile("${path.module}/cloud-init.yaml.tpl", {
      ssh_public_key = file("${path.module}/ssh_key.pub")
    })
  }
}
```

cloud-init.yaml.tpl example:
```yaml
#cloud-config
ssh_authorized_keys:
  - ${ssh_public_key}

runcmd:
  - curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true K3S_KUBECONFIG_MODE="644" sh -
```

After creating an instance, wait 60-90 seconds for cloud-init to complete before SSH access.

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

## SSH Key Management

### Generate SSH Key Pair Locally
```bash
ssh-keygen -t ed25519 -f ~/.ssh/scaleway -N ""
```
Creates `~/.ssh/scaleway` (private) and `~/.ssh/scaleway.pub` (public).

### Create SSH Key in Scaleway
```hcl
resource "scaleway_iam_ssh_key" "ci_cd" {
  name       = "ci-cd"
  public_key = file("~/.ssh/scaleway.pub")
  project_id = var.project_id
}
```

### Retrieve Existing SSH Key
```hcl
data "scaleway_account_ssh_key" "my_ssh_key" {
  ssh_key_id = "11111111-1111-1111-1111-111111111111"
}
```

### Use SSH Key in Instance
Via cloud-init (recommended):
```hcl
resource "scaleway_instance_server" "example" {
  user_data = {
    "user-data" = templatefile("${path.module}/cloud-init.yaml.tpl", {
      ssh_public_key = data.scaleway_account_ssh_key.my_ssh_key.public_key
    })
  }
}
```

Or directly via Scaleway's SSH key feature (limited to account-level keys):
```hcl
resource "scaleway_instance_server" "example" {
  # SSH keys must be passed via cloud-init for project-level IAM keys
}
```

### SSH Variables
```hcl
variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/scaleway"
}
```

```bash
terraform apply -var="ssh_private_key_path=~/.ssh/scaleway"
```

## SSH Access to Instances (Project-Specific)

This project includes an ED25519 SSH key (`ssh_key`) for the `github-actions` user:

```bash
# Connect to instance using the project's SSH key
ssh -i ./ssh_key root@<instance_ip>
```

The cloud-init configuration in `terraform/cloud-init.yaml.tpl` includes:
- ED25519 key for github-actions (matches `ssh_key`)
- RSA key for local development

If SSH fails after instance creation:
1. Wait 60-90 seconds for cloud-init to complete
2. Clear old host keys: `ssh-keygen -R <instance_ip>`
3. Verify cloud-init was applied with correct `user-data` key (not `cloud-init`)

## Troubleshooting

### Cloud-init runcmd not executing
If `runcmd` in cloud-init doesn't execute on Scaleway:
1. Check cloud-init logs: `ssh root@<ip> 'journalctl -u cloud-init --no-pager -n 50'`
2. Check output log: `ssh root@<ip> 'cat /var/log/cloud-init-output.log'`
3. Manually run commands if needed:
   ```bash
   curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true K3S_KUBECONFIG_MODE="644" sh
   systemctl enable k3s
   systemctl start k3s
   ```

**Security Notes:**
- Never commit private keys to version control
- Add private keys to `.gitignore`
- Use environment variables or secret management for CI/CD
