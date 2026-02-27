# Local GPU Deployment

Deploy GPU workloads on your local gaming computer (192.168.1.96) with RTX 5070 Ti.

## Prerequisites

- NixOS machine with NVIDIA GPU (RTX 5070 Ti)
- K3s installed and running
- SSH access to the machine
- Network connectivity from your local machine

## Quick Start

### Step 1: Initialize Local GPU Computer

Run this from your current machine to configure passwordless sudo:

```bash
./init-local-gpu.sh
```

You will be prompted for the sudo password: `azugo;ih`

### Step 2: Deploy GPU Operator

Once passwordless sudo is configured, deploy the GPU Operator:

```bash
./deploy-local-gpu.sh
```

This will:
1. Copy kubeconfig to your local machine
2. Install NVIDIA GPU Operator
3. Install Prometheus for monitoring
4. Configure GPU node

### Step 3: Deploy Workloads

After the GPU Operator is running, deploy your workloads:

```bash
export KUBECONFIG=~/.kube/config-gpu-local
kubectl apply -f k8s/05-moshi-setup.yaml
kubectl apply -f k8s/09-moshi-inference-timeslicing.yaml
```

## Architecture

```
┌─────────────────────────────────────────────┐
│   Gaming PC (192.168.1.96)                  │
│                                             │
│  ┌──────────────────┐  ┌─────────────────┐ │
│  │   K3s Server     │  │  NVIDIA GPU     │ │
│  │   (Control Plane)│  │  RTX 5070 Ti    │ │
│  └──────────────────┘  │  (16GB VRAM)    │ │
│                        └─────────────────┘ │
│  ┌──────────────────────────────────────┐ │
│  │   GPU Operator                        │ │
│  │   - Device Plugin                     │ │
│  │   - GPU Manager                       │ │
│  └──────────────────────────────────────┘ │
│                                             │
│  ┌──────────────────────────────────────┐ │
│  │   Workloads                           │ │
│  │   - Moshi Inference (Time Slicing)    │ │
│  │   - Monitoring (Prometheus/Grafana)   │ │
│  └──────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Credentials

See `credentials-local.env` for configuration.

## Monitoring

Access Grafana dashboard:

```bash
kubectl port-forward -n monitoring service/grafana 3000:80
```

Then open: http://localhost:3000

Default credentials: `admin/admin`

## Troubleshooting

### GPU Not Detected

```bash
# Check GPU is visible
nvidia-smi

# Check GPU operator logs
kubectl logs -n gpu-operator deployment/gpu-operator
```

### Node Not Ready

```bash
# Check K3s status
ssh jeremie@192.168.1.96 "sudo systemctl status k3s"

# Get kubeconfig
./deploy-local-gpu.sh
```

### Kubeconfig Issues

```bash
# Regenerate kubeconfig
ssh -i ssh_key jeremie@192.168.1.96 "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config-gpu-local
sed -i 's|127.0.0.1|192.168.1.96|g' ~/.kube/config-gpu-local
chmod 600 ~/.kube/config-gpu-local
export KUBECONFIG=~/.kube/config-gpu-local
```

## Comparison: Scaleway vs Local

| Aspect | Scaleway (dev/prod) | Local GPU |
|--------|---------------------|-----------|
| Location | Cloud | Home network |
| GPU | L4-24GB / H100 | RTX 5070 Ti |
| Control Plane | Cloud instance | Gaming PC |
| Network | Public IP | Private IP (192.168.1.96) |
| Access | Tailscale VPN | SSH key |
| Cost | €0.85-€4/hour | Free (own hardware) |
| MIG Support | Yes (H100, L4) | No (consumer GPU) |
| Time Slicing | Yes | Yes |

## Files

- `credentials-local.env` - SSH and cluster configuration
- `setup-local-gpu.sh` - Run on gaming PC to configure system
- `deploy-local-gpu.sh` - Deploy GPU Operator from local machine
- `init-local-gpu.sh` - Initial setup wrapper script