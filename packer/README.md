# Packer GPU Image Builder

This directory contains Packer templates to build a custom GPU-enabled image for Scaleway with:
- Ubuntu 22.04 base
- NixOS package manager
- NVIDIA GPU drivers (CUDA 12.2)
- Docker with NVIDIA runtime
- K3s Kubernetes
- Pre-pulled Docker images for GPU workloads

## Project Structure

```
packer/
├── nixos/
│   ├── nixos.pkr.hcl          # Main Packer template
│   ├── variables.pkr.hcl      # Variable definitions
│   ├── variables.json         # Example variables
│   ├── scripts/
│   │   ├── 01-base-packages.sh
│   │   ├── 02-install-nix.sh
│   │   ├── 03-nvidia-drivers.sh
│   │   ├── 04-docker.sh
│   │   ├── 05-k3s.sh
│   │   ├── 06-prepull-images.sh
│   │   ├── 07-open-ports.sh
│   │   └── 99-cleanup.sh
│   └── output-*/              # Build output
├── nixos-config/
│   ├── configuration.nix      # NixOS configuration
│   └── hardware-configuration.nix
└── Makefile.packer            # Build automation
```

## Prerequisites

- Packer >= 1.10.0
- Scaleway account with API keys
- SSH key pair for instance access

## Environment Variables

Set these environment variables:

```bash
export SCW_ACCESS_KEY="your-access-key"
export SCW_SECRET_KEY="your-secret-key"
export SCW_PROJECT_ID="your-project-id"
```

## Quick Start

### Local Build

```bash
# Initialize Packer
make init

# Validate templates
make validate

# Build the image
make build
```

### Using GitHub Actions

1. Go to GitHub Actions
2. Run "Build GPU Image with Packer"
3. Optionally customize image name and server type

## Build Options

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | Scaleway project ID | (required) |
| `image_name` | Name for the built image | `gpu-k3s-docker-nixos-23.11` |
| `server_type` | Scaleway server type | `H100-1-80G` |
| `zone` | Scaleway zone | `fr-par-2` |
| `region` | Scaleway region | `fr-par` |

## Pre-installed Software

### GPU Support
- NVIDIA Driver 535 Server
- CUDA 12.2
- NVIDIA Container Toolkit
- GPU monitoring tools (gpustat, nvtop, gpu-burn)

### Container Runtime
- Docker 24.x with overlay2
- NVIDIA Container Runtime
- Containerd
- nerdctl, crictl

### Kubernetes
- K3s (latest)
- kubectl
- helm
- k9s
- kubectx/kubens
- kind, minikube

### Pre-pulled Images
The image includes pre-pulled Docker images for:
- NVIDIA CUDA (12.2, 12.1, 12.0, 11.8)
- TensorFlow, PyTorch, JAX
- GPU Operator components
- Prometheus, Grafana, Loki
- Kubernetes core components
- Various ML/LLM images

## Usage

After launching an instance from the built image:

```bash
# Check GPU
nvidia-smi

# Check Docker
docker ps

# Check K3s
systemctl start k3s
kubectl get nodes
```

## Troubleshooting

### Build fails with SSH timeout
- Increase `ssh_timeout` in the Packer template
- Check Scaleway API credentials

### NVIDIA driver not loaded
- Check kernel modules: `lsmod | grep nvidia`
- Check driver installation: `nvidia-smi`

### Docker without NVIDIA runtime
- Check daemon.json configuration
- Restart Docker: `systemctl restart docker`
