# Moshi Helm Chart - ArgoCD Deployment

This directory contains ArgoCD manifests to deploy the Moshi AI voice chat application from the Helm chart at https://github.com/jeremiepas/moshi.

## Prerequisites

Before deploying, verify the following are installed and configured:

### Cluster Requirements

```bash
# Check Longhorn is installed and running
kubectl get pods -n longhorn-system
kubectl get storageclass longhorn

# Check GPU operator is configured
kubectl get pods -n gpu-operator
kubectl get nodes -o json | jq '.items[].status.allocatable | keys | .[]' | grep nvidia

# Verify ingress controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Verify ArgoCD is installed
kubectl get pods -n argocd
kubectl get svc -n argocd
```

### Required Secrets

1. **HuggingFace Token** (sealed):
   ```bash
   # Get your HF token from https://huggingface.co/settings/tokens
   
   # Create and seal the secret
   kubectl create secret generic moshi-hf-token \
     --from-literal=HF_TOKEN=hf_xxxxxxxxxxxxxxxx \
     --namespace=moshi \
     --dry-run=client -o yaml | \
     kubeseal --scope=namespace-wide --namespace=moshi > sealed-hf-token.yaml
   
   # Apply the sealed secret
   kubectl apply -f sealed-hf-token.yaml
   ```

## Deployment Steps

Deploy the manifests in order:

### 1. Create Namespace and Resources

```bash
# Apply namespace with GPU labels
kubectl apply -f 01-namespace.yaml
```

### 2. Create ConfigMap with Helm Values

```bash
# Apply values ConfigMap
kubectl apply -f 02-values-configmap.yaml
```

### 3. Create Sealed Secret

```bash
# IMPORTANT: You must seal the secret first!
# See Prerequisites section above for sealing instructions

# Apply the sealed secret
kubectl apply -f 03-sealed-secrets.yaml
```

### 4. Deploy Model Download Job (Optional)

```bash
# Run model download before the application
# This ensures the model is available before backend starts
kubectl apply -f 05-model-download-job.yaml

# Wait for job to complete
kubectl wait --for=condition=complete --timeout=30m job/moshi-model-download -n moshi
```

### 5. Create ArgoCD Application

```bash
# Apply the ArgoCD Application resource
kubectl apply -f 04-argocd-application.yaml
```

### 6. Verify Deployment

```bash
# Check ArgoCD application status
argocd app get moshi-helm

# Or via kubectl
kubectl get application -n argocd moshi-helm
```

## Verification Commands

### Check ArgoCD Application Status

```bash
# Get application status
kubectl get application -n argocd moshi-helm -o yaml

# Watch sync status
argocd app wait moshi-helm --health

# View application events
kubectl describe application -n argocd moshi-helm
```

### Check Pod Status

```bash
# Watch all pods in moshi namespace
kubectl get pods -n moshi -w

# Check specific pod status
kubectl describe pod -n moshi -l app.kubernetes.io/name=moshi

# View pod logs
kubectl logs -n moshi -l app.kubernetes.io/component=backend --tail=100 -f
kubectl logs -n moshi -l app.kubernetes.io/component=webui --tail=100 -f

# Check init container logs (if applicable)
kubectl logs -n moshi -l app.kubernetes.io/component=backend -c model-download --tail=100
```

### Check Model Download Completion

```bash
# Check job status
kubectl get job -n moshi moshi-model-download

# View job logs
kubectl logs -n moshi -l job-name=moshi-model-download --tail=500

# Check PVC usage
kubectl get pvc -n moshi
kubectl describe pvc -n moshi moshi-model-pvc

# Verify model files exist (exec into pod)
kubectl exec -n moshi deploy/moshi-backend -- ls -la /models/

# Check model cache size
kubectl exec -n moshi deploy/moshi-backend -- du -sh /models/*
```

### Check GPU Allocation

```bash
# Check GPU nodes
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, gpus: .status.allocatable["nvidia.com/gpu"]}'

# Check GPU allocation on pods
kubectl get pods -n moshi -o json | jq '.items[] | {name: .metadata.name, gpus: .spec.containers[].resources.limits["nvidia.com/gpu"]}'

# Check GPU usage via nvidia-smi (on node)
kubectl exec -n moshi deploy/moshi-backend -- nvidia-smi

# Check GPU operator logs if issues
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset --tail=100
```

### Check Ingress

```bash
# Check ingress resource
kubectl get ingress -n moshi
kubectl describe ingress -n moshi moshi-webui

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100

# Test connectivity (from within cluster)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://moshi-webui.moshi.svc.cluster.local:8080

# External access
# Visit: https://moshi.montech.tail21c10a.ts.net
```

## Troubleshooting

### Pods Stuck in Init State

**Symptoms:** Backend pod stuck in Init or Pending

**Diagnosis:**
```bash
# Check init container logs
kubectl logs -n moshi <pod-name> -c model-download

# Check events
kubectl describe pod -n moshi <pod-name>

# Check if PVC is bound
kubectl get pvc -n moshi

# Check storage class
kubectl get storageclass longhorn
```

**Solutions:**
- Ensure Longhorn is running: `kubectl get pods -n longhorn-system`
- Check PVC capacity: May need more storage or different storage class
- Verify model download job completed successfully
- If init container fails, check HF_TOKEN secret exists

### GPU Not Allocated

**Symptoms:** Pod stuck in Pending with "Insufficient nvidia.com/gpu"

**Diagnosis:**
```bash
# Check node GPU capacity
kubectl describe node <node-name> | grep -A5 "Capacity"

# Check GPU operator
kubectl get pods -n gpu-operator

# Check device plugin logs
kubectl logs -n gpu-operator -l app=nvidia-device-plugin-daemonset

# Verify node labels
kubectl get nodes --show-labels | grep nvidia
```

**Solutions:**
- Ensure GPU operator is running: `kubectl get pods -n gpu-operator`
- Check node has GPU label: `kubectl label node <node> nvidia.com/gpu.present=true`
- Restart device plugin if needed
- Verify MIG or time-slicing is properly configured

### Model Download Failures

**Symptoms:** Job fails or model files not found

**Diagnosis:**
```bash
# Check job logs
kubectl logs -n moshi job/moshi-model-download

# Check if secret exists
kubectl get secret -n moshi moshi-hf-token

# Verify HF_TOKEN is valid
echo "hf_xxxx" | huggingface-cli login

# Check PVC size
kubectl get pvc -n moshi moshi-model-pvc
```

**Solutions:**
- Verify HF_TOKEN is valid at https://huggingface.co/settings/tokens
- Ensure token has read access to `kyutai/moshiko-pytorch-bf16`
- Check PVC has enough space (50Gi minimum)
- Re-run job: `kubectl delete job -n moshi moshi-model-download && kubectl apply -f 05-model-download-job.yaml`

### Storage Issues

**Symptoms:** PVC Pending, volume mount failures

**Diagnosis:**
```bash
# Check PVC status
kubectl get pvc -n moshi
kubectl describe pvc -n moshi moshi-model-pvc

# Check Longhorn volumes
kubectl get volumes -n longhorn-system
kubectl get replicas -n longhorn-system

# Check Longhorn manager
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100
```

**Solutions:**
- Ensure Longhorn is installed and nodes are schedulable
- Check if Longhorn default storage class exists: `kubectl get sc`
- Verify nodes have Longhorn labels: `kubectl get nodes --show-labels`
- Restart Longhorn manager pods if stuck

### Ingress Not Working

**Symptoms:** Cannot access moshi.montech.tail21c10a.ts.net

**Diagnosis:**
```bash
# Check ingress resource
kubectl get ingress -n moshi
kubectl describe ingress -n moshi moshi-webui

# Check service
kubectl get svc -n moshi

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Test DNS resolution
nslookup moshi.montech.tail21c10a.ts.net

# Check Tailscale funnel/status
tailscale status
```

**Solutions:**
- Verify ingress controller is running: `kubectl get pods -n ingress-nginx`
- Check service endpoints: `kubectl get endpoints -n moshi`
- Verify Tailscale is connected and funnel is active
- Test with port-forward: `kubectl port-forward -n moshi svc/moshi-webui 8080:8080`

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Ingress       │────▶│   Moshi WebUI   │────▶│  Moshi Backend  │
│   (nginx)       │     │   (React UI)    │     │   (Python API)  │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                       │
                              ┌──────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Model PVC     │
                    │  (Longhorn 50Gi)│
                    │  /models        │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   GPU (NVIDIA)  │
                    │  L4 / MIG / etc │
                    └─────────────────┘
```

## File Reference

| File | Purpose |
|------|---------|
| `01-namespace.yaml` | Creates `moshi` namespace with GPU support |
| `02-values-configmap.yaml` | Helm chart values configuration |
| `03-sealed-secrets.yaml` | SealedSecret template for HF_TOKEN |
| `04-argocd-application.yaml` | ArgoCD Application resource |
| `05-model-download-job.yaml` | Pre-deployment model download job |

## Maintenance

### Updating the Chart

```bash
# Update ArgoCD app to sync latest changes
argocd app sync moshi-helm

# Or via kubectl
kubectl annotate application -n argocd moshi-helm argocd.argoproj.io/refresh=hard
```

### Redeploy Model

```bash
# Delete and recreate model download job
kubectl delete job -n moshi moshi-model-download
kubectl apply -f 05-model-download-job.yaml
```

### Cleanup

```bash
# Delete ArgoCD application (removes all resources)
kubectl delete -f 04-argocd-application.yaml

# Or via ArgoCD CLI
argocd app delete moshi-helm

# Clean up namespace
kubectl delete namespace moshi
```

## Support

For issues with:
- **Moshi application**: https://github.com/jeremiepas/moshi/issues
- **Helm chart**: https://github.com/jeremiepas/moshi/tree/main/helm
- **Infrastructure**: Check cluster logs and this troubleshooting guide
