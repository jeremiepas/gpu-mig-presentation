#!/bin/bash
# Pre-pull Docker images for GPU workloads
set -e

echo "=== Step 6: Pre-pulling Docker images ==="

export DEBIAN_FRONTEND=noninteractive

# Wait for Docker to be ready
echo "Waiting for Docker..."
until docker info > /dev/null 2>&1; do
    sleep 5
done
echo "Docker is ready"

# Function to pull image with retry
pull_image() {
    local image=$1
    echo "Pulling: $image"
    docker pull "$image" || echo "Warning: Failed to pull $image (continuing)"
}

# ============================================================
# NVIDIA GPU Operator Images
# ============================================================
echo "Pulling GPU Operator images..."
pull_image "nvcr.io/nvidia/k8s/driver:12.4.0"
pull_image "nvcr.io/nvidia/k8s/container-toolkit:v1.14.1"
pull_image "nvcr.io/nvidia/k8s/container-toolkit:v1.15.0"
pull_image "nvcr.io/nvidia/cloud-native/k8s-device-plugin:v1.14.1"
pull_image "nvcr.io/nvidia/k8s/dcgm-exporter:3.1.8-3.1.0-ubuntu22.04"
pull_image "nvcr.io/nvidia/gpu-operator:v23.9.0"
pull_image "nvcr.io/nvidia/gpu-operator:v24.1.0"
pull_image "nvcr.io/nvidia/k8s-driver-manager:v0.7.0"
pull_image "nvcr.io/nvidia/k8s-dra-driver:v0.14.1"

# ============================================================
# NVIDIA CUDA Images
# ============================================================
echo "Pulling CUDA images..."
pull_image "nvidia/cuda:12.2.2-runtime-ubuntu22.04"
pull_image "nvidia/cuda:12.2.2-devel-ubuntu22.04"
pull_image "nvidia/cuda:12.2.2-base-ubuntu22.04"
pull_image "nvidia/cuda:12.1.1-runtime-ubuntu22.04"
pull_image "nvidia/cuda:12.1.1-devel-ubuntu22.04"
pull_image "nvidia/cuda:12.0.1-runtime-ubuntu22.04"
pull_image "nvidia/cuda:11.8.0-runtime-ubuntu22.04"

# ============================================================
# Machine Learning Frameworks
# ============================================================
echo "Pulling ML framework images..."
pull_image "tensorflow/tensorflow:latest-gpu"
pull_image "tensorflow/tensorflow:2.15.0-gpu"
pull_image "pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime"
pull_image "pytorch/pytorch:2.1.0-cuda12.1-cudnn8-devel"
pull_image "pytorch/pytorch:2.2.0-cuda12.1-cudnn8-runtime"
pull_image "pytorch/pytorch:2.2.0-cuda12.1-cudnn8-devel"

# JAX, Triton, etc.
pull_image "nvidia/jax:latest"
pull_image "nvidia/triton-server:latest"

# ============================================================
# LLM / Inference Images
# ============================================================
echo "Pulling LLM/Inference images..."
pull_image "ghcr.io/huggingface/text-generation-inference:latest"
pull_image "ghcr.io/huggingface/text-generation-inference:2.0"
pull_image "ghcr.io/huggingface/transformers-pytorch-gpu:latest"
pull_image "ghcr.io/lmms/llama.cpp:latest"

# Moshi demo images
pull_image "moshi4/llava-1.5-7b-hf:latest"
pull_image "moshi4/llava-1.5-7b-delta:latest"
pull_image "moshi4/llava-1.6-vicuna-7b-hf:latest"
pull_image "moshi4/llava-1.6-mistral-7b-hf:latest"

# Ollama
pull_image "ollama/ollama:latest"
pull_image "ollama/ollama:latest"

# ============================================================
# Kubernetes Core Images
# ============================================================
echo "Pulling Kubernetes core images..."
pull_image "rancher/mirrored-coreos-etcd:v3.5.9"
pull_image "rancher/mirrored-library-busybox:1.36"
pull_image "rancher/mirrored-library-traefik:2.10.4"
pull_image "rancher/klipper-lb:v0.4.0"
pull_image "rancher/mirrored-metrics-server:v0.6.3"
pull_image "rancher/local-path-provisioner:v0.0.24"
pull_image "rancher/k3s:v1.28.4-k3s1"

# ============================================================
# Prometheus & Monitoring
# ============================================================
echo "Pulling monitoring images..."
pull_image "prom/prometheus:v2.47.0"
pull_image "prom/prometheus:v2.48.0"
pull_image "prom/prometheus:v2.50.0"
pull_image "prom/node-exporter:v1.6.1"
pull_image "prom/alertmanager:v0.26.0"
pull_image "grafana/grafana:10.2.0"
pull_image "grafana/grafana:10.2.1"
pull_image "grafana/loki:2.9.0"
pull_image "grafana/promtail:2.9.0"

# ============================================================
# GPU Testing & Benchmarking
# ============================================================
echo "Pulling GPU testing images..."
pull_image "uogbuji/gpu_burn:latest"
pull_image "nvidia/gpu-burn:latest"
pull_image "fedebirge/gpu-burn:latest"

# ============================================================
# Storage Images
# ============================================================
echo "Pulling storage images..."
pull_image "rancher/local-path-provisioner:v0.0.24"
pull_image "quay.io/external_storage/nfs-client-provisioner:v4.0.2"
pull_image "quay.io/minio/minio:latest"

# ============================================================
# Utility Images
# ============================================================
echo "Pulling utility images..."
pull_image "curlimages/curl:latest"
pull_image "busybox:latest"
pull_image "alpine:latest"
pull_image "debian:bookworm-slim"
pull_image "ubuntu:22.04"
pull_image "ubuntu:23.10"

# ============================================================
# GitOps Tools
# ============================================================
echo "Pulling GitOps images..."
pull_image "ghcr.io/fluxcd/flux2:latest"
pull_image "argoproj/argo-workflows-cli:latest"
pull_image "argoproj/argo-cd:latest"

# ============================================================
# Ingress & Networking
# ============================================================
echo "Pulling networking images..."
pull_image "registry.k8s.io/ingress-nginx/controller:v1.9.4"
pull_image "registry.k8s.io/coredns/coredns:v1.11.1"
pull_image "registry.k8s.io/kube-proxy:v1.28.4"
pull_image "registry.k8s.io/pause:3.9"

# ============================================================
# Kube State Metrics
# ============================================================
echo "Pulling Kube State Metrics images..."
pull_image "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.0"
pull_image "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.9.2"

# ============================================================
# NVIDIA Deep Learning Container (DGX Compatible)
# ============================================================
echo "Pulling NVIDIA NGC images..."
pull_image "nvcr.io/nvidia/ngc-context:latest"
pull_image "nvcr.io/hpc/rapids:latest"

# Save all images to tar for offline use
echo "Saving images to tar..."
docker save -o /root/docker-images.tar \
    nvidia/cuda:12.2.2-runtime-ubuntu22.04 \
    nvidia/cuda:12.2.2-devel-ubuntu22.04 \
    tensorflow/tensorflow:latest-gpu \
    pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime \
    pytorch/pytorch:2.1.0-cuda12.1-cudnn8-devel \
    prom/prometheus:v2.47.0 \
    grafana/grafana:10.2.0 \
    nvcr.io/nvidia/gpu-operator:v23.9.0 \
    nvcr.io/nvidia/cloud-native/k8s-device-plugin:v1.14.1 \
    nvcr.io/nvidia/k8s/dcgm-exporter:3.1.8-3.1.0-ubuntu22.04 \
    moshi4/llava-1.5-7b-hf:latest \
    ghcr.io/huggingface/text-generation-inference:latest \
    ollama/ollama:latest \
    ollama/ollama:latest || echo "Warning: Some images may not have been pulled"

echo "=== Docker images pre-pulled ==="
echo "Images saved to: /root/docker-images.tar"

# List all pulled images
echo "Pulled images:"
docker images --format "{{.Repository}}:{{.Tag}}"
