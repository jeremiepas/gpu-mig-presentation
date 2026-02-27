# ArgoCD Deployment Plan

## Project Context

This is a GPU MIG (Multi-Instance GPU) vs Time Slicing demo project built on a NixOS-based K3s cluster. The project demonstrates GPU resource virtualization for NVIDIA GPUs with support for both MIG and time-slicing configurations.

### Current Environment

- **Cluster Type**: NixOS-based K3s with Traefik ingress
- **Kubectl Access**: `export KUBECONFIG="$HOME/.kube/config-k3s-remote"`
- **GPU**: NVIDIA L4-24GB (Scaleway H100-1-80G instance type)
- **MIG Profiles**: `mig.1g.6gb`, `mig.2g.12gb`, `mig.3g.24gb`
- **Time Slicing**: 4 GPU replicas by default
- **Ingress**: Traefik (already configured in cluster)
- **ArgoCD Access Target**: `https://<domainname>/argocd`
- **Secret Management**: Infisical

### Existing Workloads

The project currently deploys the following components:

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| GPU Operator | `gpu-operator` | NVIDIA device plugin and GPU management |
| Prometheus | `monitoring` | Metrics collection and storage |
| Grafana | `monitoring` | Visualization and dashboards |
| Moshi Demo | `moshi-demo` | AI inference workloads |
| Billing Exporter | `monitoring` | Scaleway billing metrics |

---

## Phase 1: NixOS K3s ArgoCD Deployment

### 1.1 Create Namespace

**File**: `nixos/argocd/00-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/part-of: gitops
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-application-controller
  namespace: argocd
```

**Deployment Command**:
```bash
export KUBECONFIG="$HOME/.kube/config-k3s-remote"
kubectl apply -f nixos/argocd/00-namespace.yaml
```

---

### 1.2 Install ArgoCD Core Components

**File**: `nixos/argocd/01-argocd-install.yaml`

This manifest installs ArgoCD using the official upstream manifests with NixOS K3s-specific modifications:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  # Enable server-side apply for better CRD handling
  application.resourceTrackingMethod: annotation
  # Disable TLS on server since we use Traefik
  server.insecure: "true"
  # Configure dex for future Infisical integration
  dex.config: |
    connectors:
      - type: oidc
        id: infisical
        name: Infisical
        config:
          issuer: "https://app.infisical.com"
          clientID: "$INFISICAL_CLIENT_ID"
          clientSecret: "$INFISICAL_CLIENT_SECRET"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, *, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    g, admin, role:admin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-server
        app.kubernetes.io/part-of: argocd
    spec:
      serviceAccountName: argocd-server
      containers:
        - name: argocd-server
          image: quay.io/argoproj/argocd:v2.10.0
          args:
            - /usr/local/bin/argocd-server
            - --insecure
            - --basehref
            - /argocd
          ports:
            - containerPort: 8080
              name: http
            - containerPort: 8083
              name: grpc
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: tls-certs
              mountPath: /app/config/tls
      volumes:
        - name: tls-certs
          emptyDir: {}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-repo-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-repo-server
    app.kubernetes.io/part-of: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-repo-server
        app.kubernetes.io/part-of: argocd
    spec:
      serviceAccountName: argocd-repo-server
      containers:
        - name: argocd-repo-server
          image: quay.io/argoproj/argocd:v2.10.0
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-application-controller
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-application-controller
    app.kubernetes.io/part-of: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-application-controller
        app.kubernetes.io/part-of: argocd
    spec:
      serviceAccountName: argocd-application-controller
      containers:
        - name: argocd-application-controller
          image: quay.io/argoproj/argocd:v2.10.0
          command:
            - argocd-application-controller
          args:
            - --app-resync
            - "60"
            - --repo-server-timeout-seconds
            - "180"
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: argocd-redis
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-redis
    app.kubernetes.io/part-of: argocd
spec:
  serviceName: argocd-redis
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-redis
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-redis
        app.kubernetes.io/part-of: argocd
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          ports:
            - containerPort: 6379
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 250m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080
      name: http
    - port: 443
      targetPort: 8080
      nodePort: 30443
      name: https
  selector:
    app.kubernetes.io/name: argocd-server
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-repo-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-repo-server
    app.kubernetes.io/part-of: argocd
spec:
  ports:
    - port: 8081
      targetPort: 8081
  selector:
    app.kubernetes.io/name: argocd-repo-server
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-redis
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-redis
    app.kubernetes.io/part-of: argocd
spec:
  ports:
    - port: 6379
      targetPort: 6379
  selector:
    app.kubernetes.io/name: argocd-redis
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-application-controller
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-application-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-application-controller
subjects:
  - kind: ServiceAccount
    name: argocd-application-controller
    namespace: argocd
```

**Deployment Command**:
```bash
kubectl apply -f nixos/argocd/01-argocd-install.yaml
```

---

### 1.3 Configure Ingress with /argocd Path

**File**: `nixos/argocd/02-ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.pathprefixstrip: "false"
    traefik.ingress.kubernetes.io/router.middlewares: argocd-headers@kubernetescrd
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  rules:
    - host: montech.tail21c10a.ts.net
      http:
        paths:
          - path: /argocd
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
  tls:
    - hosts:
        - montech.tail21c10a.ts.net
      secretName: argocd-tls-secret
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: argocd-headers
  namespace: argocd
spec:
  headers:
    customRequestHeaders:
      X-Forwarded-Proto: "https"
      X-Forwarded-Port: "443"
    customResponseHeaders:
      X-Frame-Options: "SAMEORIGIN"
      X-XSS-Protection: "1; mode=block"
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-tls-secret
  namespace: argocd
type: kubernetes.io/tls
stringData:
  tls.crt: |
    # Replace with actual certificate or use cert-manager
  tls.key: |
    # Replace with actual key or use cert-manager
```

**Deployment Command**:
```bash
kubectl apply -f nixos/argocd/02-ingress.yaml
```

---

### 1.4 Setup Infisical Integration for Secrets

**File**: `nixos/argocd/04-infisical-secrets.yaml`

```yaml
# External Secrets Operator configuration for Infisical integration
apiVersion: v1
kind: Namespace
metadata:
  name: external-secrets
  labels:
    app.kubernetes.io/name: external-secrets
---
# ClusterSecretStore for Infisical
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: infisical-backend
spec:
  provider:
    infisical:
      auth:
        universalAuthCredentials:
          clientId:
            name: infisical-auth-secret
            namespace: external-secrets
            key: clientId
          clientSecret:
            name: infisical-auth-secret
            namespace: external-secrets
            key: clientSecret
      secretsScope:
        projectSlug: "gpu-mig-presentation"
        environmentSlug: "prod"
        recursive: true
---
# Secret for Infisical authentication
apiVersion: v1
kind: Secret
metadata:
  name: infisical-auth-secret
  namespace: external-secrets
type: Opaque
stringData:
  clientId: "${INFISICAL_CLIENT_ID}"
  clientSecret: "${INFISICAL_CLIENT_SECRET}"
---
# Example ExternalSecret for ArgoCD admin password
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-admin-secret
  namespace: argocd
spec:
  refreshInterval: "1h"
  secretStoreRef:
    kind: ClusterSecretStore
    name: infisical-backend
  target:
    name: argocd-initial-admin-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: "ARGOCD_ADMIN_PASSWORD"
        property: value
---
# ExternalSecret for Git repository credentials
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-git-creds
  namespace: argocd
spec:
  refreshInterval: "1h"
  secretStoreRef:
    kind: ClusterSecretStore
    name: infisical-backend
  target:
    name: argocd-git-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: "GITHUB_USERNAME"
        property: value
    - secretKey: password
      remoteRef:
        key: "GITHUB_TOKEN"
        property: value
```

**Prerequisites**:
```bash
# Install External Secrets Operator
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/v0.9.0/deploy/crds/bundle.yaml
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/v0.9.0/deploy/bundle.yaml

# Verify External Secrets Operator is running
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets --timeout=120s
```

**Deployment Command**:
```bash
# Set environment variables before applying
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"

# Apply the secrets configuration
envsubst < nixos/argocd/04-infisical-secrets.yaml | kubectl apply -f -
```

---

### 1.5 Retrieve Initial Admin Password

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Or if using Infisical integration
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI
# URL: https://montech.tail21c10a.ts.net/argocd
# Username: admin
# Password: <retrieved from above>
```

---

## Phase 2: K8s Version ArgoCD Deployment

### 2.1 Create Namespace

**File**: `k8s/argocd/00-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/part-of: gitops
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-application-controller
  namespace: argocd
```

---

### 2.2 Install ArgoCD Core Components

**File**: `k8s/argocd/01-argocd-install.yaml`

Similar to NixOS version but with standard Kubernetes service type (LoadBalancer):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  application.resourceTrackingMethod: annotation
  server.insecure: "true"
  url: "https://4edcb867-7b4e-4890-b3d6-7912075f20d8.pub.instances.scw.cloud/argocd"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-server
        app.kubernetes.io/part-of: argocd
    spec:
      serviceAccountName: argocd-server
      containers:
        - name: argocd-server
          image: quay.io/argoproj/argocd:v2.10.0
          args:
            - /usr/local/bin/argocd-server
            - --insecure
            - --basehref
            - /argocd
          ports:
            - containerPort: 8080
              name: http
            - containerPort: 8083
              name: grpc
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  annotations:
    service.beta.kubernetes.io/scw-loadbalancer-type: "lb-s"
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
      name: http
    - port: 443
      targetPort: 8080
      name: https
  selector:
    app.kubernetes.io/name: argocd-server
```

---

### 2.3 Configure Ingress

**File**: `k8s/argocd/02-ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  rules:
    - host: 4edcb867-7b4e-4890-b3d6-7912075f20d8.pub.instances.scw.cloud
      http:
        paths:
          - path: /argocd
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
```

---

### 2.4 Scaleway-Specific Considerations

**LoadBalancer Configuration**:
```yaml
# Additional annotation for Scaleway LoadBalancer
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-lb
  namespace: argocd
  annotations:
    service.beta.kubernetes.io/scw-loadbalancer-type: "lb-s"
    service.beta.kubernetes.io/scw-loadbalancer-zone: "fr-par-1"
spec:
  type: LoadBalancer
  ports:
    - port: 443
      targetPort: 8080
  selector:
    app.kubernetes.io/name: argocd-server
```

---

## Phase 3: Application Management

### 3.1 Define ArgoCD Applications

**File**: `nixos/argocd/03-applications.yaml`

```yaml
# Application for GPU Operator
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gpu-operator
  namespace: argocd
  labels:
    app.kubernetes.io/name: gpu-operator
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/01-gpu-operator.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: gpu-operator
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - Replace=true
---
# Application for Runtime Class
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nvidia-runtimeclass
  namespace: argocd
  labels:
    app.kubernetes.io/name: nvidia-runtimeclass
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/00-nvidia-runtimeclass.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: gpu-operator
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
# Application for GPU Configuration (MIG or Time Slicing)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gpu-config
  namespace: argocd
  labels:
    app.kubernetes.io/name: gpu-config
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/02-timeslicing-config.yaml  # or 02-mig-config.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: gpu-operator
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - Replace=true
  ignoreDifferences:
    - group: apps
      kind: DaemonSet
      jsonPointers:
        - /spec/template/spec/containers/0/resources
---
# Application for Namespaces
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: namespaces
  namespace: argocd
  labels:
    app.kubernetes.io/name: namespaces
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/00-namespaces.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
# Application for Monitoring Stack
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-stack
  namespace: argocd
  labels:
    app.kubernetes.io/name: monitoring-stack
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/
    directory:
      include: "03-prometheus.yaml,04-grafana.yaml,04-grafana-datasources.yaml,12-kube-state-metrics.yaml,09-node-exporter.yaml"
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
---
# Application for Moshi Setup
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moshi-setup
  namespace: argocd
  labels:
    app.kubernetes.io/name: moshi-setup
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/05-moshi-setup.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: moshi-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 3
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 5m
---
# Application for Moshi Inference (Time Slicing)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moshi-inference-timeslicing
  namespace: argocd
  labels:
    app.kubernetes.io/name: moshi-inference-timeslicing
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/06-moshi-timeslicing.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: moshi-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
---
# Application for Moshi Inference (MIG)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: moshi-inference-mig
  namespace: argocd
  labels:
    app.kubernetes.io/name: moshi-inference-mig
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/07-moshi-mig.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: moshi-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
---
# Application for Ingress Routes
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ingress-routes
  namespace: argocd
  labels:
    app.kubernetes.io/name: ingress-routes
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/08-ingress-routes.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
# Application for Billing Exporter
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: billing-exporter
  namespace: argocd
  labels:
    app.kubernetes.io/name: billing-exporter
    app.kubernetes.io/part-of: gpu-mig-demo
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/gpu-mig-presentation
    targetRevision: main
    path: k8s/08-scaleway-billing.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### 3.2 Application Dependencies

Define the order of deployment:

```yaml
# AppProject with resource constraints
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: gpu-mig-demo
  namespace: argocd
spec:
  description: GPU MIG Demo Project
  sourceRepos:
    - 'https://github.com/YOUR_ORG/gpu-mig-presentation'
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: rbac.authorization.k8s.io
      kind: ClusterRole
    - group: rbac.authorization.k8s.io
      kind: ClusterRoleBinding
    - group: node.k8s.io
      kind: RuntimeClass
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
```

---

## File Structure

```
nixos/argocd/
├── 00-namespace.yaml              # ArgoCD namespace
├── 01-argocd-install.yaml         # Core ArgoCD components
├── 02-ingress.yaml                # Traefik ingress configuration
├── 03-applications.yaml           # Application definitions
└── 04-infisical-secrets.yaml      # External secrets integration

k8s/argocd/
├── 00-namespace.yaml              # ArgoCD namespace
├── 01-argocd-install.yaml         # Core ArgoCD components
├── 02-ingress.yaml                # Ingress configuration
├── 03-applications.yaml           # Application definitions
└── 04-infisical-secrets.yaml      # External secrets integration
```

---

## Deployment Commands

### NixOS K3s Deployment

```bash
# 1. Set kubeconfig
export KUBECONFIG="$HOME/.kube/config-k3s-remote"

# 2. Create namespace
kubectl apply -f nixos/argocd/00-namespace.yaml

# 3. Install ArgoCD
kubectl apply -f nixos/argocd/01-argocd-install.yaml

# 4. Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
kubectl wait --for=condition=available deployment/argocd-repo-server -n argocd --timeout=120s

# 5. Configure ingress
kubectl apply -f nixos/argocd/02-ingress.yaml

# 6. Configure Infisical secrets (optional)
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"
envsubst < nixos/argocd/04-infisical-secrets.yaml | kubectl apply -f -

# 7. Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 8. Apply applications
kubectl apply -f nixos/argocd/03-applications.yaml
```

### Standard K8s Deployment

```bash
# Similar to NixOS but use k8s/argocd/ paths
export KUBECONFIG="$HOME/.kube/config"
kubectl apply -f k8s/argocd/00-namespace.yaml
kubectl apply -f k8s/argocd/01-argocd-install.yaml
kubectl apply -f k8s/argocd/02-ingress.yaml
kubectl apply -f k8s/argocd/04-infisical-secrets.yaml
kubectl apply -f k8s/argocd/03-applications.yaml
```

---

## Technical Details

### ArgoCD Version

- **Version**: v2.10.0 (latest stable as of Q1 2025)
- **Image**: `quay.io/argoproj/argocd:v2.10.0`

### Resource Requirements

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| argocd-server | 100m | 500m | 256Mi | 512Mi |
| argocd-repo-server | 100m | 500m | 256Mi | 512Mi |
| argocd-application-controller | 250m | 1000m | 512Mi | 1Gi |
| argocd-redis | 100m | 250m | 128Mi | 256Mi |

### Service Types

- **NodePort**: For NixOS K3s (accessible via node IP)
- **LoadBalancer**: For standard K8s on Scaleway

### Path-Based Routing

ArgoCD is configured to use `/argocd` path prefix with the `--basehref /argocd` flag.

---

## Verification Steps

```bash
# Check all pods are running
kubectl get pods -n argocd

# Verify services
kubectl get svc -n argocd

# Check ingress
kubectl get ingress -n argocd

# View ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# Test ArgoCD CLI
argocd login montech.tail21c10a.ts.net:80 --insecure --grpc-web-root-path /argocd

# List applications
argocd app list

# Sync an application
argocd app sync gpu-operator
```

---

## Troubleshooting

### ArgoCD Server Not Accessible

```bash
# Check ingress controller
kubectl get pods -n kube-system | grep traefik

# Verify ingress rules
kubectl describe ingress -n argocd

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=100
```

### Permission Issues

```bash
# Check RBAC
kubectl get clusterrole argocd-application-controller
kubectl get clusterrolebinding argocd-application-controller

# Verify service account
kubectl get sa -n argocd
```

### Infisical Integration Issues

```bash
# Check External Secrets Operator logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=100

# Verify ClusterSecretStore
kubectl describe clustersecretstore infisical-backend

# Check ExternalSecret status
kubectl describe externalsecret argocd-admin-secret -n argocd
```

---

## Next Steps

1. **Configure Git Repository**: Update `repoURL` in application manifests to point to your Git repository
2. **Set up Webhooks**: Configure GitHub/GitLab webhooks for automatic sync
3. **Configure RBAC**: Define fine-grained permissions for team members
4. **Enable Notifications**: Set up Slack/Email notifications for sync events
5. **Backup**: Configure backup of ArgoCD configuration

---

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Ingress Configuration](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)
- [External Secrets Operator](https://external-secrets.io/)
- [Infisical Documentation](https://infisical.com/docs)
- [Traefik Ingress Documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-ingress/)
