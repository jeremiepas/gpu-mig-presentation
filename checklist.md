# NVIDIA k8s-device-plugin Quick Start Checklist

## Prerequisites
- [x] NVIDIA drivers installed (~= 384.81)
- [x] nvidia-container-toolkit installed (>= 1.7.0)
- [x] nvidia-container-runtime configured as the default low-level runtime
- [x] Kubernetes version >= 1.10

## Preparing Your GPU Nodes

### Install the NVIDIA Container Toolkit
- [x] Follow installation guide: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
- [x] For containerd configuration: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#configuring-containerd-for-kubernetes

### Configure Container Runtime
- [x] Configure nvidia-container-runtime as default low-level runtime
- [x] For containerd, add configuration to enable nvidia runtime
- [x] Restart container runtime after applying configuration changes

## Enabling GPU Support in Kubernetes

### Deploy the Device Plugin
- [x] Apply the daemonset:
  ```
  kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml
  ```
- [x] Verify the device plugin pod is running:
  ```
  kubectl get pods -n kube-system | grep nvidia
  ```

### Verify GPU Detection
- [x] Check node capacity for GPU resources:
  ```
  kubectl describe node <node-name> | grep -A 10 "Capacity"
  ```
- [x] Device plugin logs should show GPU detection:
  ```
  kubectl logs -n kube-system nvidia-device-plugin-daemonset-<id>
  ```

## Running GPU Jobs

### Create a Test Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  restartPolicy: Never
  containers:
    - name: cuda-container
      image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0
      resources:
        limits:
          nvidia.com/gpu: 1 # requesting 1 GPU
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

### Verify GPU Access
- [ ] Pod should be in Running state
- [ ] Check logs for successful GPU computation
- [ ] nvidia-smi should show GPU processes when running workloads

## Deploying Grafana for Visualization

### Deploy Grafana
- [x] Deploy Grafana to the cluster:
  ```bash
  kubectl apply -f grafana-deployment.yaml
  ```
- [x] Verify Grafana pod is running:
  ```bash
  kubectl get pods -n grafana
  ```
- [x] Check Grafana service and its NodePort:
  ```bash
  kubectl get svc -n grafana
  ```

### Configure Ingress for Tailscale Access
- [x] Remove conflicting ingress:
  ```bash
  kubectl delete ingress -n monitoring main-ingress
  ```
- [x] Create new ingress for Grafana:
  ```bash
  kubectl apply -f grafana-ingress.yaml
  ```
- [x] Verify ingress configuration:
  ```bash
  kubectl describe ingress -n grafana grafana-ingress
  ```

### Access Grafana UI
- [x] Access Grafana via NodePort: http://<NODE_IP>:32518
- [ ] Access Grafana via Tailscale URL: http://montech.tail21c10a.ts.net
- [ ] Login with default credentials (admin/admin)

## Current Status

### Environment Information
- Kubernetes version: v1.34.4+k3s1
- Node name: montech
- Node IP: 192.168.1.96
- Container runtime: containerd://2.1.5-k3s1

### Resolved Issues
- [x] NVIDIA drivers working (verified via nvidia-smi on host)
- [x] Device plugin daemonset running
- [x] Device plugin successfully detecting GPUs
- [x] GPU resources visible in node capacity:
  ```
  nvidia.com/gpu: 1
  ```
- [x] Device plugin registered with Kubelet successfully
- [x] Grafana deployed to the cluster
- [x] Grafana service available on NodePort 32518
- [x] Grafana ingress configured for Tailscale access

### Known Issues
- [ ] Tailscale URL access timing out - possible DNS or network configuration issue

### Resolution Summary
1. [x] Created symlink for nvidia-ctk at expected location:
   ```bash
   sudo ln -s /home/jeremie/.nix-profile/bin/nvidia-ctk /usr/bin/nvidia-ctk
   ```
2. [x] Deployed custom device plugin configuration with "tegra" device discovery strategy
3. [x] Added required environment variables and volume mounts for NixOS compatibility
4. [x] Verified GPU resources are now advertised by the node
5. [x] Deployed Grafana to visualize GPU metrics
6. [x] Configured ingress for Tailscale access (but experiencing timeout issues)