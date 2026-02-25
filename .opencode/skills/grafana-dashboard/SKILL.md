---
name: grafana-dashboard
description: Create and manage Grafana dashboards for GPU monitoring without pod recreation
license: MPL-2.0
compatibility: opencode
metadata:
  audience: developers
  workflow: monitoring
---

## What I do
- Create Grafana dashboards for GPU MIG vs Time Slicing comparison
- Configure dashboards for Prometheus metrics visualization
- Manage dashboard provisioning and updates
- Update dashboards WITHOUT recreating Grafana pod

## Key Concepts

### Two Methods to Manage Dashboards

| Method | Use Case | Pod Restart Needed |
|--------|----------|-------------------|
| ConfigMap Provisioning | GitOps, version control | No (with `allowUiUpdates: true`) |
| Grafana REST API | Quick updates, scripting | No |

### Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  ConfigMap      │────▶│  Grafana Pod     │────▶│  Dashboard UI   │
│  (dashboards)   │     │  (provisioning)  │     │  (auto-refresh) │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  Grafana API     │
                       │  (port 3000)     │
                       └──────────────────┘
```

## Dashboard Management Methods

### Method 1: ConfigMap Provisioning (Recommended for GitOps)

**Critical Configuration** - Must have `allowUiUpdates: true`:

```yaml
# In k8s/04-grafana.yaml under grafana-dashboards ConfigMap
dashboards.yaml: |
  apiVersion: 1
  providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true  # KEY: allows updates without pod restart
    options:
      path: /etc/grafana/provisioning/dashboards
```

**Update Dashboard (no restart needed):**
```bash
# Option 1: Edit directly
kubectl edit configmap grafana-dashboards -n monitoring

# Option 2: Apply YAML file
kubectl apply -f k8s/04-grafana.yaml

# Grafana will auto-reload within 10 seconds
# Or force quick restart (no downtime):
kubectl rollout restart deployment/grafana -n monitoring
```

### Method 2: Grafana REST API (Immediate, no ConfigMap)

**Setup port forward:**
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
```

**API Operations:**

```bash
GRAFANA_URL="http://localhost:3000/api"
AUTH="admin:admin"

# List all dashboards
curl -s -u "$AUTH" "$GRAFANA_URL/api/search?type=dash-db" | jq

# Get dashboard by UID
curl -s -u "$AUTH" "$GRAFANA_URL/api/dashboards/uid/gpu-comparison" | jq

# Create/update dashboard
curl -s -u "$AUTH" -X POST \
  -H "Content-Type: application/json" \
  "$GRAFANA_URL/api/dash  -d 'boards/db" \
{
    "dashboard": {
      "title": "My Dashboard",
      "uid": "my-dashboard-uid",
      "version": 1,
      "panels": [...]
    },
    "message": "Created via API",
    "overwrite": true
  }'

# Delete dashboard
curl -s -u "$AUTH" -X DELETE "$GRAFANA_URL/api/dashboards/uid/my-dashboards"
```

## Workflow

### Add New Dashboard

1. **Create dashboard JSON** (save as `my-dashboard.json`)
2. **Add to ConfigMap** in `k8s/04-grafana.yaml`:
   ```yaml
   data:
     my-dashboard.json: |
       { ... dashboard json ... }
   ```
3. **Apply changes:**
   ```bash
   kubectl apply -f k8s/04-grafana.yaml
   ```
4. **Verify:**
   ```bash
   kubectl exec -it -n monitoring deployment/grafana -- \
     curl -s http://localhost:3000/api/search?query= | jq
   ```

### Update Existing Dashboard

**ConfigMap method:**
```bash
vim k8s/04-grafana.yaml  # Edit dashboard JSON
kubectl apply -f k8s/04-grafana.yaml
```

**API method:**
```bash
# Get current
curl -s -u "admin:admin" \
  "http://localhost:3000/api/dashboards/uid/gpu-comparison" > current.json

# Edit and increment version
jq '.dashboard.version += 1' current.json > updated.json

# Push update
curl -s -u "admin:admin" -X POST \
  -H "Content-Type: application/json" \
  "http://localhost:3000/api/dashboards/db" -d @updated.json
```

## Dashboard JSON Structure

```json
{
  "title": "Dashboard Title",
  "uid": "unique-id",
  "version": 1,
  "refresh": "5s",
  "timezone": "browser",
  "panels": [
    {
      "id": 1,
      "title": "Panel Title",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "targets": [{
        "expr": "prometheus_query",
        "legendFormat": "{{label}}",
        "refId": "A"
      }],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "thresholds": {
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 90}
            ]
          }
        }
      }
    }
  ],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "timepicker": {}
}
```

## GPU-Specific Prometheus Queries

```promql
# GPU Utilization
nvidia_dcgm_exporter_gpu_utilization_gpu_percent

# GPU Memory Used (GB)
nvidia_dcgm_exporter_gpu_memory_used_bytes / 1024 / 1024 / 1024

# GPU Memory Total (GB)
nvidia_dcgm_exporter_gpu_memory_total_bytes / 1024 / 1024 / 1024

# GPU Temperature
nvidia_dcgm_exporter_gpu_temperature_celsius

# GPU Power Usage
nvidia_dcgm_exporter_gpu_power_usage_watts

# Container GPU usage
container_spec_resource_limits_nvidia_com_gpu
```

## Troubleshooting

### Dashboards not appearing
```bash
# Check ConfigMap mounted
kubectl describe pod -n monitoring grafana-xxx | grep -A5 "Mounts"

# Check provisioning config
kubectl exec -it -n monitoring deployment/grafana -- \
  cat /etc/grafana/provisioning/dashboards/dashboard.yaml

# Check logs
kubectl logs -n monitoring deployment/grafana | grep -i dashboard

# Validate JSON
python3 -c "import json; json.load(open('k8s/04-grafana.yaml'))"
```

### Changes not reflected
1. Ensure `allowUiUpdates: true` is set
2. Wait 10 seconds (updateIntervalSeconds)
3. Or force restart: `kubectl rollout restart deployment/grafana -n monitoring`

## Useful Commands

```bash
# Port forward
kubectl port-forward -n monitoring svc/grafana 3000:3000 &

# Restart (if needed)
kubectl rollout restart deployment/grafana -n monitoring

# List dashboards
kubectl exec -it -n monitoring deployment/grafana -- \
  curl -s http://localhost:3000/api/search?type=dash-db | jq '.[].title'

# Grafana health
kubectl exec -it -n monitoring deployment/grafana -- \
  curl -s http://localhost:3000/api/health | jq
```

## Dashboard Files

- `k8s/04-grafana.yaml` - Grafana deployment + dashboard ConfigMaps
- `k8s/04-grafana-datasources.yaml` - Prometheus datasource

## Best Practices

- Use ConfigMaps for GitOps (version control)
- Use API for quick testing/iteration
- Increment version on each update
- Keep consistent UIDs for updates
- Test queries in Prometheus first
- Use templating for dynamic filtering
