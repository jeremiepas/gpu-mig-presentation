# Moshi AI Services - Implementation Todo

## Overview

This project creates a complete Moshi AI deployment system with a **frontend web UI service** and **worker service** for speech and vision processing. The system is designed to work together as an integrated platform deployed on Kubernetes with support for both Time Slicing and MIG GPU modes.

### Goals
- Create a production-ready Moshi AI inference system
- Separate frontend (web UI) and backend (inference workers)
- Support both speech-to-text and text-to-speech capabilities
- Vision processing capabilities via Moshi Vision
- GPU optimization with Time Slicing and MIG profiles
- Containerized deployment with Helm charts
- Automated CI/CD via GitHub Actions

### Resources
- **Kyutai Website**: https://kyutai.org/
- **Moshi Vision Demo**: https://kyutai.org/moshivis
- **Technical Report**: [arxiv.org/abs/2410.00037](https://arxiv.org/abs/2410.00037)
- **GitHub Repository**: https://github.com/kyutai-labs/moshi
- **HuggingFace Model**: [kyutai/moshiko-pytorch-bf16](https://huggingface.co/kyutai/moshiko-pytorch-bf16)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         Ingress (nginx)                                  │ │
│  │  /moshi-web ──────┐    /api ───────────────┐    /metrics ──────────┐   │ │
│  └───────────────────┼────────────────────────┼───────────────────────┘   │
│                      │                        │                            │
│  ┌───────────────────▼────────────────────────▼─────────────────────────┐  │
│  │                    Frontend Service (moshi-web)                       │  │
│  │  ┌───────────────────────────────────────────────────────────────┐  │  │
│  │  │  React/Vue Web UI                                              │  │  │
│  │  │  - Audio recording/playback                                    │  │  │
│  │  │  - Real-time chat interface                                    │  │  │
│  │  │  - Vision upload/display                                       │  │  │
│  │  │  - Connection to WebSocket for streaming                       │  │  │
│  │  └───────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                      │                                                        │
│                      │ REST API / gRPC / WebSocket                           │
│                      ▼                                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Worker Service (moshi-worker)                       │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────┐  │  │
│  │  │ STT Worker      │  │ TTS Worker      │  │ Vision Worker        │  │  │
│  │  │ (Speech-to-Text)│  │ (Text-to-Speech)│  │ (Image Analysis)     │  │  │
│  │  │                 │  │                 │  │                      │  │  │
│  │  │ • Audio input   │  │ • Text input    │  │ • Image input        │  │  │
│  │  │ • Transcription │  │ • Audio output  │  │ • Analysis           │  │  │
│  │  │ • Streaming     │  │ • Voice clone   │  │ • Description        │  │  │
│  │  └─────────────────┘  └─────────────────┘  └──────────────────────┘  │  │
│  │                                                                        │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │ Model Cache (Shared PVC)                                        │  │  │
│  │  │ • /models/moshi/moshiko-pytorch-bf16                             │  │  │
│  │  │ • /models/moshi/moshika-vis-pytorch-bf16                        │  │  │
│  │  │ • HuggingFace cache                                             │  │  │
│  │  └────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                      │                                                        │
│  ┌───────────────────▼────────────────────────────────────────────────────┐  │
│  │                         GPU Resources                               │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────────┐  │  │
│  │  │ Time Slicing    │  │ MIG 1g.6gb      │  │ MIG 2g.12gb         │  │  │
│  │  │ Mode            │  │ Profile         │  │ Profile             │  │  │
│  │  │                 │  │                 │  │                     │  │  │
│  │  │ • Shared GPU    │  │ • 6GB VRAM      │  │ • 12GB VRAM         │  │  │
│  │  │ • Multiple pods │  │ • 1 GPU slice   │  │ • 2 GPU slices      │  │  │
│  │  │ • Context       │  │ • Isolated      │  │ • Higher throughput │  │  │
│  │  │   switching     │  │                 │  │                     │  │  │
│  │  └─────────────────┘  └─────────────────┘  └──────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    Supporting Infrastructure                           │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │  │
│  │  │ Prometheus  │  │ Grafana     │  │ Redis       │  │ Model     │  │  │
│  │  │ (Metrics)   │  │ (Dashboard) │  │ (Queue)     │  │ Downloader│  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Current State

### Existing Infrastructure
- **Packer Configuration**: `packer/gpu-moshi/gpu-moshi.pkr.hcl` - GPU image builder
- **Moshi Dependencies**: `packer/gpu-moshi/scripts/05-moshi-deps.sh` - Python env, PyTorch, audio tools
- **Kubernetes Manifests**:
  - `k8s/05-moshi-setup.yaml` - Model download job
  - `k8s/06-moshi-timeslicing.yaml` - Time slicing demo pods
  - `k8s/07-moshi-mig.yaml` - MIG demo pods
  - `k8s/08-moshi-vis.yaml` - Moshi vision deployment
  - `k8s/09-moshi-inference-timeslicing.yaml` - Inference with metrics (Time Slicing)
  - `k8s/10-moshi-inference-mig.yaml` - Inference with metrics (MIG)
- **CI/CD**: `.github/workflows/deploy.yml` - Terraform + K8s deployment

### What's Missing
- [ ] Frontend web UI service
- [ ] Production-ready worker service
- [ ] Inter-service communication layer
- [ ] Helm charts for parameterized deployment
- [ ] Dedicated GitHub workflow for Moshi services

---

## Phase 1: Foundation & Planning

### 1.1 Project Structure Setup
- [ ] Create `moshi-builder/` directory structure:
  ```
  moshi-builder/
  ├── frontend/                 # Web UI service
  │   ├── src/
  │   ├── public/
  │   ├── Dockerfile
  │   └── package.json
  ├── worker/                   # Inference worker
  │   ├── src/
  │   ├── models/
  │   ├── Dockerfile
  │   └── requirements.txt
  ├── shared/                   # Shared components
  │   ├── proto/               # gRPC/protobuf definitions
  │   └── types/               # Shared TypeScript/Python types
  ├── helm/                     # Helm charts
  │   ├── moshi-frontend/
  │   └── moshi-worker/
  └── .github/workflows/         # CI/CD workflows
      └── moshi-deploy.yml
  ```
- [ ] Initialize frontend project (React/Vue with TypeScript)
- [ ] Initialize worker project (Python with FastAPI/gRPC)
- [ ] Set up shared protocol buffer definitions
- [ ] Create root-level docker-compose.yml for local development

### 1.2 Technical Specifications Document
- [ ] Define API contracts (REST + WebSocket for frontend, gRPC for internal)
- [ ] Define message formats for audio/vision streaming
- [ ] Document GPU resource requirements per mode:
  | Mode | GPU Memory | Use Case |
  |------|------------|----------|
  | Time Slicing | Shared 24GB | Development, multiple pods |
  | MIG 1g.6gb | 6GB | Lightweight inference |
  | MIG 2g.12gb | 12GB | Standard inference |
  | MIG 3g.24gb | 24GB | Vision + heavy inference |
- [ ] Document model requirements and caching strategy

### 1.3 Local Development Environment
- [ ] Create `docker-compose.yml` with:
  - Frontend service (hot reload)
  - Worker service (with GPU passthrough option)
  - Redis for message queue
  - MinIO for model storage (S3-compatible)
- [ ] Create development scripts (`scripts/dev-start.sh`, `scripts/dev-stop.sh`)
- [ ] Document local setup in `moshi-builder/README.md`

---

## Phase 2: Frontend Service (moshi-frontend)

### 2.1 Core Framework Setup
- [ ] Initialize React 18+ with TypeScript
- [ ] Configure build system (Vite or similar)
- [ ] Set up linting (ESLint) and formatting (Prettier)
- [ ] Configure testing framework (Vitest + React Testing Library)
- [ ] Set up Docker multi-stage build

### 2.2 UI Components
- [ ] **Layout Components**:
  - [ ] Navigation bar with mode indicator (Time Slicing/MIG)
  - [ ] Connection status indicator
  - [ ] GPU resource usage display
- [ ] **Audio Components**:
  - [ ] Audio recorder (WebRTC getUserMedia)
  - [ ] Audio player with waveform visualization
  - [ ] Real-time streaming interface
- [ ] **Chat Components**:
  - [ ] Message list (user/AI messages)
  - [ ] Message input (text + voice toggle)
  - [ ] Typing/streaming indicators
- [ ] **Vision Components**:
  - [ ] Image upload (drag & drop)
  - [ ] Image preview/thumbnails
  - [ ] Vision analysis results display

### 2.3 State Management & API
- [ ] Set up state management (Zustand/Redux Toolkit)
- [ ] Implement WebSocket client for real-time streaming
- [ ] Create REST API client for configuration/control
- [ ] Implement audio streaming buffer management
- [ ] Add connection retry logic with exponential backoff

### 2.4 Frontend Dockerfile
```dockerfile
# Multi-stage build for production optimization
FROM node:20-alpine AS builder
# ... build steps ...

FROM nginx:alpine AS production
# ... nginx config, copy build artifacts ...
```

---

## Phase 3: Worker Service (moshi-worker)

### 3.1 Core Python Setup
- [ ] Initialize Python project with Poetry/pip
- [ ] Create FastAPI application structure
- [ ] Set up gRPC server for internal communication
- [ ] Configure logging (structured JSON logs)
- [ ] Implement health check endpoints

### 3.2 Model Management
- [ ] Create model loader with caching:
  ```python
  class MoshiModelManager:
      def load_model(self, model_name: str, device: str) -> Model
      def get_cache_status(self) -> CacheStatus
      def preload_models(self, models: List[str])
  ```
- [ ] Implement model warm-up on startup
- [ ] Add model versioning support
- [ ] Create model download utility (reuse from `05-moshi-deps.sh`)

### 3.3 Inference Workers
- [ ] **STT Worker** (Speech-to-Text):
  - [ ] Audio preprocessing (resampling, normalization)
  - [ ] Moshi STT inference endpoint
  - [ ] Streaming transcription support
  - [ ] Batch processing for non-streaming
- [ ] **TTS Worker** (Text-to-Speech):
  - [ ] Text preprocessing and phonemization
  - [ ] Moshi TTS inference endpoint
  - [ ] Audio post-processing
  - [ ] Voice cloning support (if available)
- [ ] **Vision Worker** (Image Analysis):
  - [ ] Image preprocessing (resize, normalize)
  - [ ] Moshi Vision inference endpoint
  - [ ] Batch processing for multiple images

### 3.4 Message Queue Integration
- [ ] Implement Redis/RabbitMQ client
- [ ] Create job queue for async processing
- [ ] Implement worker pool pattern for scalability
- [ ] Add job status tracking and callbacks

### 3.5 Worker Dockerfile
```dockerfile
FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04
# Python setup, dependency installation
# Model cache mounting
# Non-root user for security
```

### 3.6 Prometheus Metrics
- [ ] Expose `/metrics` endpoint
- [ ] Track metrics:
  - `moshi_inference_duration_seconds` (histogram)
  - `moshi_queue_size` (gauge)
  - `moshi_active_workers` (gauge)
  - `moshi_tokens_generated_total` (counter)
  - `moshi_gpu_memory_bytes` (gauge)
  - `moshi_requests_total` (counter, by model type)

---

## Phase 4: Kubernetes Deployment

### 4.1 Namespace & Configuration
- [ ] Create `moshi-services` namespace
- [ ] ConfigMap for service configuration:
  - Model paths
  - Redis connection
  - GPU mode settings
  - Feature flags
- [ ] Secret for HuggingFace token (if needed)

### 4.2 Shared Storage
- [ ] PersistentVolumeClaim for model cache:
  ```yaml
  # 50GB for multiple models
  storageClassName: local-path  # or appropriate storage class
  accessMode: ReadWriteMany     # For multiple workers
  ```
- [ ] InitContainer for model pre-download

### 4.3 Frontend Deployment
- [ ] Deployment with 2-3 replicas (stateless)
- [ ] Service (ClusterIP)
- [ ] Ingress rule: `/moshi` → frontend
- [ ] Resource limits: 500m CPU, 512Mi memory

### 4.4 Worker Deployment
- [ ] Deployment with GPU resources:
  ```yaml
  resources:
    limits:
      nvidia.com/gpu: "1"
      memory: "8Gi"
      cpu: "4"
  ```
- [ ] Separate deployments for Time Slicing vs MIG modes
- [ ] HorizontalPodAutoscaler based on queue depth
- [ ] Service for internal communication
- [ ] PodDisruptionBudget for availability

### 4.5 Redis Deployment (Optional)
- [ ] Redis StatefulSet for message queue
- [ ] Persistent storage for queue durability
- [ ] Service for worker connections

---

## Phase 5: Helm Charts

### 5.1 Chart Structure
```
helm/
├── moshi-frontend/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-timeslicing.yaml
│   ├── values-mig.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── configmap.yaml
└── moshi-worker/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-timeslicing.yaml
    ├── values-mig.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── hpa.yaml
        ├── pdb.yaml
        └── configmap.yaml
```

### 5.2 Chart Features
- [ ] Configurable GPU mode (timeslicing/mig/none)
- [ ] Configurable replica counts
- [ ] Resource limits/requests templating
- [ ] Ingress host configuration
- [ ] Model cache PVC size configuration
- [ ] Feature flags (enable/disable vision, TTS, STT)

### 5.3 Values Files
- [ ] `values.yaml` - Default configuration
- [ ] `values-timeslicing.yaml` - Time Slicing overrides
- [ ] `values-mig.yaml` - MIG mode overrides
- [ ] `values-dev.yaml` - Development overrides (lower resources)

---

## Phase 6: GitHub Actions Workflow

### 6.1 Workflow File: `moshi-builder-deploy.yml`
```yaml
name: Build and Deploy Moshi Services
on:
  push:
    paths:
      - 'moshi-builder/**'
      - '.github/workflows/moshi-builder-deploy.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment (dev/prod)'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - prod
      gpu_mode:
        description: 'GPU Mode (timeslicing/mig)'
        required: true
        default: 'timeslicing'
        type: choice
        options:
          - timeslicing
          - mig
```

### 6.2 Workflow Jobs
- [ ] **Build Frontend**:
  - Build Docker image
  - Push to registry (GitHub Container Registry or Scaleway)
  - Tag with commit SHA and `latest`
- [ ] **Build Worker**:
  - Build multi-arch Docker image (AMD64 for GPU nodes)
  - Push to registry
  - Scan for vulnerabilities
- [ ] **Deploy to Kubernetes**:
  - Configure kubeconfig from remote server
  - Apply Helm chart with appropriate values
  - Wait for rollout completion
  - Verify health checks
- [ ] **Post-Deploy Verification**:
  - Check pod status
  - Verify ingress accessibility
  - Run smoke tests

### 6.3 Workflow Features
- [ ] Conditional builds (only if files changed)
- [ ] Environment-specific deployments
- [ ] Slack/Discord notifications on success/failure
- [ ] Artifact retention for rollback

---

## Phase 7: Testing & Documentation

### 7.1 Testing
- [ ] **Unit Tests**:
  - Frontend component tests
  - Worker inference tests (mocked models)
  - API contract tests
- [ ] **Integration Tests**:
  - End-to-end audio streaming test
  - Vision upload and analysis test
  - Load testing (k6 or Locust)
- [ ] **GPU Tests**:
  - Verify GPU accessibility in pods
  - Test Time Slicing mode with multiple pods
  - Test MIG mode with isolated instances

### 7.2 Documentation
- [ ] `moshi-builder/README.md` - Project overview and quick start
- [ ] `moshi-builder/docs/ARCHITECTURE.md` - Detailed architecture
- [ ] `moshi-builder/docs/DEPLOYMENT.md` - Deployment guide
- [ ] `moshi-builder/docs/API.md` - API reference
- [ ] `moshi-builder/docs/DEVELOPMENT.md` - Local development guide

### 7.3 Operational Runbooks
- [ ] Troubleshooting guide
- [ ] Scaling procedures
- [ ] Rollback procedures
- [ ] Monitoring and alerting guide

---

## Phase 8: Monitoring & Observability

### 8.1 Logging
- [ ] Structured JSON logging in all services
- [ ] Centralized log aggregation (Loki or similar)
- [ ] Log retention policy (7 days dev, 30 days prod)

### 8.2 Metrics
- [ ] Custom application metrics (see Phase 3.6)
- [ ] Node/GPU metrics (already available via Prometheus)
- [ ] Dashboard in Grafana:
  - Request latency by endpoint
  - Inference duration by model type
  - Queue depth and processing rate
  - GPU utilization and memory
  - Error rates

### 8.3 Alerting
- [ ] Prometheus AlertManager rules:
  - High error rate (>5% for 5m)
  - High latency (p95 > 2s for 5m)
  - GPU memory pressure (>90% for 10m)
  - Worker pod crashes
  - Queue depth growing (>100 jobs for 5m)

---

## Implementation Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Foundation | 3-4 days | None |
| Phase 2: Frontend | 5-7 days | Phase 1 |
| Phase 3: Worker | 7-10 days | Phase 1 |
| Phase 4: K8s Deployment | 3-4 days | Phase 2, 3 |
| Phase 5: Helm Charts | 2-3 days | Phase 4 |
| Phase 6: CI/CD Workflow | 2-3 days | Phase 5 |
| Phase 7: Testing & Docs | 3-4 days | Phase 6 |
| Phase 8: Monitoring | 2-3 days | Phase 6 |

**Total Estimated Duration**: 27-38 days (4-6 weeks)

---

## Quick Start Commands

```bash
# Local development
make dev-up          # Start local stack
cd moshi-builder/frontend && npm run dev
cd moshi-builder/worker && python -m uvicorn main:app --reload

# Build containers
docker build -t moshi-frontend:latest -f moshi-builder/frontend/Dockerfile .
docker build -t moshi-worker:latest -f moshi-builder/worker/Dockerfile .

# Deploy with Helm
helm install moshi ./helm/moshi-frontend -f helm/moshi-frontend/values-timeslicing.yaml
helm install moshi-worker ./helm/moshi-worker -f helm/moshi-worker/values-timeslicing.yaml

# Verify deployment
kubectl get pods -n moshi-services
kubectl logs -f deployment/moshi-worker -n moshi-services
```

---

## Notes

- The existing `k8s/08-moshi-vis.yaml` provides a reference for Moshi Vision deployment
- GPU dependencies are already handled by `packer/gpu-moshi/scripts/05-moshi-deps.sh`
- Consider using the existing Prometheus/Grafana setup from `k8s/03-prometheus.yaml` and `k8s/04-grafana.yaml`
- The CI/CD can extend the existing `.github/workflows/deploy.yml` workflow
