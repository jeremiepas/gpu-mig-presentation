# Local GPU Deployment Guide

This guide explains how to deploy the GPU MIG vs Time Slicing infrastructure on your local gaming computer with NVIDIA GPU (100.120.26.64).

## Architecture Overview

Instead of using Scaleway cloud infrastructure, this local deployment:
- Runs on your personal gaming computer (`100.120.26.64`)
- Uses K3s as the Kubernetes distribution
- Leverages your NVIDIA GeForce RTX 5070 Ti GPU
- Provides same functionality through IP-based access instead of DNS
- Maintains compatibility with existing Kubernetes manifests

## Prerequisites

1. Access to your gaming computer at `100.120.26.64`
2. NVIDIA GPU with drivers installed (verified with `nvidia-smi`)
3. SSH access using the provided `ssh_key`
4. NixOS-based system with Docker and NVIDIA Container Toolkit configured

## Setup Process

### 1. Initialize Terraform (Recommended)

```bash
# Navigate to local environment
cd terraform/environments/local

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

This will:
- Prepare your GPU machine for deployment
- Install K3s if not already present
- Copy Kubernetes manifests to the machine
- Apply core components (namespaces, GPU operator, monitoring)

### 2. Alternative: Use Deployment Script

```bash
# Source local credentials
source credentials-local.env

# Deploy the environment
./deploy-local.sh
```

## Accessing Services

Once deployment is complete, you can access:

- **Grafana**: http://100.120.26.64:30300 (admin/admin)
- **Prometheus**: http://100.120.26.64:30090
- **K3s API**: https://100.120.26.64:6443

Note: These URLs are accessible only from your local network.

## Managing GPU Modes

### Time Slicing Mode (Default)
```bash
ssh -i ssh_key jeremie@100.120.26.64 'sudo k3s kubectl apply -f ~/k8s-manifests/02-timeslicing-config.yaml'
```

### MIG Mode
```bash
ssh -i ssh_key jeremie@100.120.26.64 'sudo k3s kubectl apply -f ~/k8s-manifests/02-mig-config.yaml'
```

## Local Kubeconfig

After deployment, a kubeconfig file is retrieved and saved to:
```
~/.kube/config-gpu-local
```

To use it:
```bash
export KUBECONFIG=~/.kube/config-gpu-local
kubectl get nodes
```

Or use the provided helper functions:
```bash
# After sourcing credentials-local.env
source credentials-local.env

# SSH to GPU machine
ssh-local

# Run kubectl commands on remote machine
kubectl-local get nodes
kubectl-local get pods -A
```

## Troubleshooting

### Common Issues

1. **SSH Connection Issues**:
   - Ensure `ssh_key` permissions are correct: `chmod 400 ssh_key`
   - Verify SSH access manually: `ssh -i ssh_key jeremie@100.120.26.64`

2. **K3s Not Starting**:
   - Check service status: `ssh-local 'sudo systemctl status k3s'`
   - Restart K3s: `ssh-local 'sudo systemctl restart k3s'`

3. **GPU Not Detected**:
   - Verify drivers: `ssh-local 'nvidia-smi'`
   - Check GPU operator logs: `kubectl-local logs -n gpu-operator -l app=nvidia-device-plugin`

### Clean Up

To completely remove the local deployment:
```bash
# Remove K3s (on remote machine)
ssh -i ssh_key jeremie@100.120.26.64 'sudo /usr/local/bin/k3s-uninstall.sh'

# Remove local kubeconfig
rm -f ~/.kube/config-gpu-local

# Clean Terraform state (optional)
cd terraform/environments/local
terraform destroy
```

## Comparing with Scaleway Deployment

| Feature | Scaleway | Local |
|--------|----------|-------|
| Infrastructure | Cloud VM | Local Machine |
| Access Method | DNS-based URLs | IP-based URLs |
| GPU Type | NVIDIA L4 (24GB) | NVIDIA RTX 5070 Ti (16GB) |
| Networking | Public Internet | Local Network |
| Cost | Pay-per-hour (~€0.85/hr) | Free (existing hardware) |
| Scalability | Easy scaling up/down | Fixed hardware |

## Performance Notes

Your local RTX 5070 Ti offers significantly more VRAM (16GB vs 24GB) and likely better performance than the L4 in the Scaleway setup. However, the local deployment is constrained to your network and hardware specifications.