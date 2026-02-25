# Lk8s - Local K3s Setup

This folder contains scripts to set up a hybrid K3s cluster where:
- **K3s Server** runs on Scaleway (cloud)
- **K3s Agent** runs on your local NixOS machine with GPU

The connection between local and cloud is secured via Tailscale VPN.

## Architecture

```
┌─────────────────────────┐            ┌─────────────────────────┐
│    Scaleway Cloud       │            │   Local NixOS Machine   │
│                         │            │                         │
│  ┌───────────────────┐  │   Tailscale │  ┌───────────────────┐ │
│  │   K3s Server      │◄─┼────────────┼──►│   K3s Agent        │ │
│  │   (Control Plane)│  │   VPN      │  │   (GPU Node)       │ │
│  └───────────────────┘  │            │  └───────────────────┘ │
│                         │            │                         │
│  ┌───────────────────┐  │            │  ┌───────────────────┐ │
│  │   Tailscale       │  │            │  │   Tailscale       │ │
│  │   Server          │  │            │  │   Client          │ │
│  └───────────────────┘  │            │  └───────────────────┘ │
└─────────────────────────┘            └─────────────────────────┘
```

## Quick Start

### Step 1: Set up Scaleway (K3s Server + Tailscale)

```bash
# SSH to your Scaleway instance
ssh -i ssh_key ubuntu@<SCW_IP>

# Copy the setup script
scp Lk8s/scaleway/setup-tailscale.sh ubuntu@<SCW_IP>:/tmp/

# Run the Tailscale setup
ssh -i ssh_key ubuntu@<SCW_IP> "sudo bash /tmp/setup-tailscale.sh"

# Or with auth key:
ssh -i ssh_key ubuntu@<SCW_IP> "sudo bash /tmp/setup-tailscale.sh <TAILSCALE_AUTH_KEY>"
```

### Step 2: Get Configuration from Scaleway

```bash
# On Scaleway, get the config file
ssh -i ssh_key ubuntu@<SCW_IP> "sudo cat /root/lk8s-config.txt"
```

This will show:
- `K3S_SERVER_IP` - The Tailscale IP of the server
- `K3S_AGENT_TOKEN` - The token to join the cluster

### Step 3: Set up NixOS (Local Machine)

```bash
# 1. Add Tailscale to your NixOS configuration
# See: local/nixos-tailscale.nix

# 2. Rebuild NixOS
sudo nixos-rebuild switch

# 3. Connect Tailscale
sudo tailscale up

# 4. Wait for connection, then join K3s
./Lk8s/local/join-k3s-agent.sh <K3S_SERVER_IP> <K3S_AGENT_TOKEN> nixos-gpu
```

## Files

### Local (NixOS)

| File | Description |
|------|-------------|
| `nixos-tailscale.nix` | NixOS module to add Tailscale to your configuration.nix |
| `join-k3s-agent.sh` | Script to join the K3s cluster as an agent |
| `local.conf.example` | Example configuration file |

### Scaleway (K3s Server)

| File | Description |
|------|-------------|
| `setup-tailscale.sh` | Install and configure Tailscale on the K3s server |
| `cluster-status.sh` | Check cluster status and connected nodes |

## Usage

### Check Cluster Status (on Scaleway)

```bash
ssh -i ssh_key ubuntu@<SCW_IP> "sudo bash /tmp/Lk8s/scaleway/cluster-status.sh"
```

### Check Nodes (on local machine)

```bash
kubectl get nodes -o wide
```

### Deploy GPU Workloads

```bash
# Apply GPU manifests from the main k8s folder
kubectl apply -f k8s/00-namespaces.yaml
kubectl apply -f k8s/01-gpu-operator.yaml
# etc.
```

## Troubleshooting

### Tailscale not connecting

```bash
# On both machines
sudo tailscale status
sudo tailscale logs --no-node-ip
```

### K3s agent not joining

```bash
# Check K3s logs on local machine
sudo journalctl -u k3s-agent -f

# Check K3s server logs
ssh -i ssh_key ubuntu@<SCW_IP> "sudo journalctl -u k3s -f"
```

### Node not showing GPU

```bash
# Check nvidia-device-plugin
kubectl get pods -n nvidia-gpu-operator
kubectl describe node <node-name>
```

## Security Notes

- The `local.conf.example` file is git-ignored but contains sensitive data
- Keep your `K3S_AGENT_TOKEN` secret - anyone with it can join the cluster
- Consider using a Tailscale auth key with expiration
