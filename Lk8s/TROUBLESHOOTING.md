# K3s Hybrid Cluster - Troubleshooting Schema

## Problem Analysis

The K3s agent on NixOS (192.168.1.96) is failing with:
```
Failed to validate connection to cluster at https://100.119.182.72:6443: 
failed to get CA certs: Get "https://127.0.0.1:6444/cacerts": context deadline exceeded
```

## Root Cause

The K3s agent is trying to fetch CA certificates from `127.0.0.1` instead of the Tailscale IP. This happens because:

1. K3s agent expects to get CA certs from the server at `https://<SERVER_IP>:6444/cacerts`
2. The agent is configured to use Tailscale IP (100.119.182.72) for API server
3. But it's still trying to get certs from localhost (127.0.0.1)

## Solution

We need to provide the CA certificates to the agent manually. Here are the steps:

## Step 1: Get CA Certs from Scaleway Server

```bash
# On Scaleway (51.159.167.215)
ssh -i ssh_key root@51.159.167.215 "sudo cat /var/lib/rancher/k3s/server/tls/server-ca.crt"
```

## Step 2: Save CA Certs on NixOS

```bash
# On NixOS (192.168.1.96)
mkdir -p /etc/rancher/k3s
# Paste the CA cert here
nano /etc/rancher/k3s/server-ca.crt
```

## Step 3: Restart K3s Agent

```bash
# On NixOS
sudo systemctl restart k3s-agent
```

## Alternative Solution: Use K3s Agent Config

Create `/etc/rancher/k3s/config.yaml` on NixOS:

```yaml
server: https://100.119.182.72:6443
token: "K10e978259227d95ce11b56917280023c0be0db2e40a4cac1b0e5a9013a7b6f814f::server:183a224ac7673f9077cbf01c6d1e11fd"
node-name: nixos-gpu
node-label:
  - "nvidia.com/gpu=true"
  - "gpu=true"
node-taint:
  - "nvidia.com/gpu=true:NoSchedule"
```

## Verification Steps

1. Check if K3s agent is running:
   ```bash
   sudo systemctl status k3s-agent
   ```

2. Check agent logs:
   ```bash
   journalctl -u k3s-agent -f
   ```

3. Check if node appears in cluster (from Scaleway):
   ```bash
   kubectl get nodes
   ```

## Current Status

- Scaleway Server: 100.119.182.72 (Tailscale) / 51.159.167.215 (Public)
- NixOS Machine: 100.120.26.64 (Tailscale) / 192.168.1.96 (Local)
- Tailscale: Connected ✅
- K3s Agent: Failing (CA cert issue) ❌

## Next Actions

1. Get CA certs from Scaleway
2. Save them on NixOS
3. Restart K3s agent
4. Verify node registration
