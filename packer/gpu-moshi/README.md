# GPU Moshi Demo - Packer Template

This directory contains a Packer template for building a GPU-optimized image for the Moshi demo on Scaleway with **ALL models pre-loaded** for instant first start (10-30 seconds instead of 5-10 minutes).

## Overview

- **Base Image**: Ubuntu 22.04 LTS
- **Purpose**: GPU workloads with Moshi AI model inference demo
- **Target Instance**: Scaleway H100-1-80GB (NVIDIA L4 GPU)
- **Key Feature**: Pre-cached Moshi models in the image

## Components Installed

1. **NVIDIA Drivers** (535) + CUDA 12.2
2. **Docker** with NVIDIA Container Runtime
3. **K3s** Kubernetes (v1.28+)
4. **Moshi Dependencies**: Python, PyTorch, transformers, audio tools
5. **Pre-loaded Models**: All Moshi models cached in image
6. **Security Hardening**: UFW, fail2ban, SSH hardening

## Model Preloading Strategy

### Pre-cached Models

All Moshi models are downloaded and cached during Packer build:

| Model | Size | Location |
|-------|------|----------|
| Moshi Base | ~500MB | `/opt/moshi/models/moshi-base` |
| Voice Encoder | ~1GB | `/opt/moshi/models/voice-encoder` |
| Large LLM | ~7GB | `/opt/moshi/models/llm` |
| **Total** | **~8.5GB** | `/opt/moshi/models` |

### Instant Start Benefits

- **Before**: 5-10 minutes to download models at pod startup
- **After**: 10-30 seconds (Kubernetes scheduling + container start)
- **Symlink**: `/models` -> `/opt/moshi/models` for backward compatibility

## Quick Start

```bash
# Initialize Packer plugins
make init

# Validate template
make validate SCW_PROJECT_ID=your-project-id

# Build image
make build SCW_PROJECT_ID=your-project-id

# Or use variables file
cd packer/gpu-moshi
packer build -var-file=variables.pkrvars.hcl .
```

## Usage

### Prerequisites

- Packer >= 1.11.0
- Scaleway account with GPU instances available
- Valid `SCW_PROJECT_ID`

### Build Commands

```bash
# With environment variable
SCW_PROJECT_ID=xxx make build

# With custom image name
SCW_PROJECT_ID=xxx IMAGE_NAME=my-gpu-image make build

# With custom instance type
SCW_PROJECT_ID=xxx INSTANCE_TYPE=H100-1-80G make build
```

### Manual Packer Commands

```bash
cd packer/gpu-moshi

# Initialize
packer init .

# Validate
packer validate -var "project_id=xxx" .

# Build
packer build -var "project_id=xxx" .
```

## Kubernetes Integration

### Using hostPath Volumes

The recommended way to use pre-loaded models is via hostPath volumes:

```bash
# Apply the hostPath manifest
kubectl apply -f k8s/13-moshi-hostpath.yaml

# Check pods
kubectl get pods -n moshi-demo -o wide
```

### hostPath Manifest Features

- Mounts `/opt/moshi/models` from host to `/models` in container
- 4 replicas (configurable) for time-slicing demo
- Model manifest available at `/models/manifest.json`
- GPU resources requested and limited

### Model Access in Containers

```bash
# Inside the pod, models are available at:
/models/
/models/manifest.json
/models/moshi-base/
/models/voice-encoder/
/models/llm/
/models/huggingface/
```

### Backward Compatibility

The old `/models` path is symlinked to `/opt/moshi/models`:

```bash
ls -la /models  # -> /opt/moshi/models
```

## Post-Deployment

### GPU Mode Selection

```bash
# Enable Time Slicing (default)
gpu-mode.sh timeslicing

# Enable MIG (if supported)
gpu-mode.sh mig

# Check status
gpu-mode.sh status
```

### K3s Access

```bash
# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml

# Check node status
kubectl get nodes -o wide
```

### Model Management

```bash
# Check model status (on host)
sudo /opt/moshi/models/status.sh

# Re-initialize models
sudo /opt/moshi/models/init.sh

# Download additional models
sudo /opt/moshi/models/download.sh <model-name>
```

## Utility Scripts

| Script | Purpose |
|--------|---------|
| `gpu-status.sh` | GPU status |
| `gpu-monitor.sh` | GPU monitoring |
| `gpu-mode.sh` | Switch GPU modes |
| `moshi-verify.sh` | Verify Moshi setup |
| `moshi-gpu-test.sh` | Test GPU with PyTorch |
| `k3s-status.sh` | K3s status |
| `/opt/moshi/models/status.sh` | Model status |
| `/opt/moshi/models/init.sh` | Initialize models |

## Image Size

- **Without models**: ~15-20 GB
- **With models**: ~25-30 GB
- **Target**: ~30-40 GB total

## Tags

- `os: ubuntu`
- `version: 22.04`
- `gpu: enabled`
- `k3s: enabled`
- `docker: enabled`
- `moshi: enabled`
- `preloaded: models`

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU
lspci | grep -i nvidia
nvidia-smi
```

### K3s Not Starting

```bash
# Check logs
journalctl -u k3s -n 50
k3s-status.sh
```

### Docker GPU Access

```bash
# Test NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

### Models Not Found

```bash
# Check model status
/opt/moshi/models/status.sh

# Check symlink
ls -la /models

# Verify hostPath mount
kubectl describe pod moshi-hostpath -n moshi-demo | grep -A 10 Volumes
```

### Pod Not Starting with hostPath

```bash
# Check if the node has the model directory
ssh -i ssh_key ubuntu@<NODE_IP> "ls -la /opt/moshi/models"

# Check node selector in manifest
kubectl get nodes --show-labels | grep gpu
```

## Security Notes

- SSH key-only authentication
- UFW firewall enabled
- fail2ban for brute-force protection
- Automatic security updates enabled
- Audit logging for GPU access
- Model files read-only for security

## Model Download URLs (Reference)

For actual model downloads, configure these in `07-models-setup.sh`:

```bash
# Example HuggingFace models (uncomment and customize)
Moshi_BASE_URL="https://huggingface.co/iknow/ai-moshi/resolve/main/moshi-base"
Voice_ENCODER_URL="https://huggingface.co/.../voice-encoder"
LLM_URL="https://huggingface.co/.../llm"
```

## Build Process

The Packer build runs these steps:

1. **01-base-setup.sh** - System packages, timezone, locale
2. **02-nvidia-drivers.sh** - NVIDIA 535 + CUDA 12.2
3. **03-docker.sh** - Docker + NVIDIA runtime
4. **04-k3s.sh** - K3s Kubernetes
5. **05-moshi-deps.sh** - Python, PyTorch, audio tools
6. **06-gpu-configs.sh** - MIG and Time Slicing config
7. **07-models-setup.sh** - **Pre-download ALL models** (KEY STEP)
8. **08-security.sh** - Firewall, SSH hardening
9. **99-cleanup.sh** - Remove temp files, minimize image

## License

MIT
