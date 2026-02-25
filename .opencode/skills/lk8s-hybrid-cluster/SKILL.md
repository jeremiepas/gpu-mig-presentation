---
name: lk8s-hybrid-cluster
description: Set up hybrid K3s cluster with Tailscale VPN - K3s server on Scaleway, K3s agent on local NixOS with GPU
license: MPL-2.0
compatibility: opencode
metadata:
  audience: developers
  workflow: infrastructure
---

## What I do

Create and manage a hybrid K3s cluster where:
- **K3s Server (control plane)** runs on Scaleway cloud
- **K3s Agent (GPU node)** runs on a local NixOS machine with NVIDIA GPU
- **Tailscale VPN** provides secure connectivity between local and cloud

## Architecture

```
┌─────────────────────────┐            ┌─────────────────────────┐
│    Scaleway Cloud       │            │   Local NixOS Machine   │
│                         │            │                         │
│  ┌───────────────────┐  │   Tailscale │  ┌───────────────────┐ │
│  │   K3s Server      │◄─┼────────────┼──►│   K3s Agent        │ │
│  │   (Control Plane) │  │   VPN      │  │   (GPU Node)       │ │
│  └───────────────────┘  │            │  └───────────────────┘ │
│                         │            │                         │
│  ┌───────────────────┐  │            │  ┌───────────────────┐ │
│  │   Tailscale       │  │            │  │   Tailscale       │ │
│  │   Server          │  │            │  │   Client          │ │
│  └───────────────────┘  │            │  └───────────────────┘ │
└─────────────────────────┘            └─────────────────────────┘
```

## Files

### Local (NixOS Machine)
Located in `Lk8s/local/`:

| File | Description |
|------|-------------|
| `nixos-tailscale.nix` | NixOS module to add Tailscale to configuration.nix |
| `join-k3s-agent.sh` | Script to join K3s cluster as an agent |
| `local.conf.example` | Example configuration file |

### Scaleway (K3s Server)
Located in `Lk8s/scaleway/`:

| File | Description |
|------|-------------|
| `setup-tailscale.sh` | Install and configure Tailscale on K3s server |
| `cluster-status.sh` | Check cluster status and connected nodes |

## Setup Workflow

### Step 1: Set up Tailscale on Scaleway (K3s Server)

```bash
# Copy setup script to Scaleway
scp Lk8s/scaleway/setup-tailscale.sh ubuntu@<SCW_IP>:/tmp/

# Run Tailscale setup (with optional auth key)
ssh -i ssh_key ubuntu@<SCW_IP> "sudo bash /tmp/setup-tailscale.sh"
# Or with Tailscale auth key:
ssh -i ssh_key ubuntu@<SCW_IP> "sudo bash /tmp/setup-tailscale.sh <TAILSCALE_AUTH_KEY>"
```

Get auth key from: https://login.tailscale.com/admin/settings/keys

### Step 2: Get Configuration from Scaleway

```bash
# Get the generated config (contains K3S_SERVER_IP and K3S_AGENT_TOKEN)
ssh -i ssh_key ubuntu@<SCW_IP> "sudo cat /root/lk8s-config.txt"
```

### Step 3: Configure NixOS (Local Machine)

Add to your `configuration.nix`:

```nix
imports = [ ./Lk8s/local/nixos-tailscale.nix ];
```

Or manually add:

```nix
{ config, pkgs, ... }:
{
  services.tailscale = {
    enable = true;
    useSystemKey = true;
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };
}
```

### Step 4: Rebuild and Connect

```bash
# Rebuild NixOS
sudo nixos-rebuild switch

# Connect Tailscale
sudo tailscale up

# Wait for connection, then join K3s
./Lk8s/local/join-k3s-agent.sh <K3S_SERVER_IP> <K3S_AGENT_TOKEN> nixos-gpu
```

## Commands

### Check Cluster Status (Scaleway)

```bash
ssh -i ssh_key ubuntu@<SCW_IP> "sudo bash /tmp/Lk8s/scaleway/cluster-status.sh"
```

### Check Nodes (Local)

```bash
kubectl get nodes -o wide
```

### Check Tailscale Status

```bash
# On Scaleway
ssh -i ssh_key ubuntu@<SCW_IP> "sudo tailscale status"

# On local NixOS
sudo tailscale status
```

## Troubleshooting

### Tailscale not connecting

```bash
# Check status on both machines
sudo tailscale status

# View logs
sudo tailscale logs --no-node-ip
```

### K3s agent not joining

```bash
# Check local K3s agent logs
sudo journalctl -u k3s-agent -f

# Check K3s server logs
ssh -i ssh_key ubuntu@<SCW_IP> "sudo journalctl -u k3s -f"
```

### Verify connectivity

```bash
# Test K3s API server from local machine
nc -z -w5 <K3S_SERVER_IP> 6443

# Should return successful connection
```

## Use Cases

1. **Hybrid GPU workloads** - Run inference on local GPU while using cloud control plane
2. **Cost optimization** - Use local GPU when available, fall back to cloud
3. **Development** - Test K3s configurations locally with real GPU
4. **Disaster recovery** - Local node can operate independently if cloud goes down

## Security Notes

- Keep `K3S_AGENT_TOKEN` secret - anyone with it can join the cluster
- Use Tailscale auth keys with expiration dates
- Consider using `--operator` flag to restrict Tailscale access
- The VPN provides encryption between local and cloud nodes

## Requirements

- Scaleway instance with K3s already running
- Local NixOS machine with NVIDIA GPU
- Tailscale account (free tier works)
- SSH access to Scaleway instance
