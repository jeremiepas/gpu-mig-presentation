# MoshiVis Deployment Task

## Prerequisites

Before deploying MoshiVis, ensure you have:

1. An existing GPU infrastructure deployed using this project
2. A working Kubernetes cluster with NVIDIA GPU support
3. Access to the Kubernetes cluster via kubectl

## Deployment Steps

1. **Apply the ingress controller and MoshiVis deployment**
   ```bash
   ./tasks/deploy-moshi-vis.sh
   ```

2. **Get your instance IP**
   ```bash
   terraform -chdir=terraform output instance_ip
   ```

3. **Access MoshiVis**
   Open your browser and go to: `http://YOUR_INSTANCE_IP/moshi-vis`

## Customization

You can customize the MoshiVis deployment by modifying the `k8s/08-moshi-vis.yaml` file:

1. Change the GPU resources allocation:
   ```yaml
   resources:
     requests:
       nvidia.com/gpu: "1"
     limits:
       nvidia.com/gpu: "1"
   ```

2. Adjust CPU/memory resources as needed

3. Change the image tag if you want to use a specific version:
   ```yaml
   image: kyutai/moshika-vis-pytorch-bf16:v1.0
   ```

## Testing

After deployment, you can test MoshiVis by:

1. Getting your instance IP:
   ```bash
   terraform -chdir=terraform output instance_ip
   ```

2. Accessing it in your browser at `http://INSTANCE_IP/moshi-vis`

3. Uploading an image and speaking to MoshiVis about it

## Cleanup

To remove MoshiVis from your cluster:

```bash
./tasks/remove-moshi-vis.sh
```

Or manually delete the resources:
```bash
kubectl delete -f k8s/08-moshi-vis.yaml
kubectl delete -f k8s/09-ingress-controller.yaml
```

### Remove only the MoshiVis application (keep ingress controller)
```bash
kubectl delete -f k8s/08-moshi-vis.yaml
```