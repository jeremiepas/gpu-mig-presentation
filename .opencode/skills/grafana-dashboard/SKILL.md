---
name: grafana-dashboard
description: Create and manage Grafana dashboards for GPU monitoring
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

## Dashboard Configuration

### GPU Comparison Dashboard
The main dashboard compares GPU utilization, memory usage, and MIG instances:
- GPU Utilization % (Time Slicing vs MIG)
- Memory Usage MB (Compare Before/After)
- MIG Active Instances
- Pod Latency (ms) - Contention Indicator
- MIG Instance Status Map
- Container Restarts (Fault Isolation Test)
- Time Slicing vs MIG - Summary

### Scaleway Resources Dashboard
Additional dashboard for infrastructure monitoring:
- CPU Usage %
- Memory Usage
- Memory Usage %
- Disk Usage %
- Network Traffic
- GPU Utilization
- GPU Memory Usage
- Estimated Cost (DEV1-S)
- Estimated Monthly Cost
- Instance Uptime
- Load Average

### Application Inventory Dashboard
Simple dashboard showing application links and health status:
- Application Links (Grafana, Prometheus, ArgoCD URLs)
- Application Health Status table
- Cluster Resource Usage by namespace
- Memory Usage by namespace
- Quick Access Links with common kubectl commands

## Dashboard Files

The dashboards are defined in Kubernetes ConfigMaps:
- `grafana-dashboards` ConfigMap contains the dashboard JSON definitions
- `grafana-provisioning` ConfigMap configures dashboard provisioning

## Deployment

Dashboards are automatically provisioned when Grafana starts through the provisioning configuration mounted at `/etc/grafana/provisioning/dashboards/dashboard.yaml`.

## Customization

To add or modify dashboards:
1. Edit the dashboard JSON in the `grafana-dashboards` ConfigMap
2. Update the provisioning configuration if needed
3. Apply the changes with `kubectl apply -f k8s/04-grafana.yaml`

## Best Practices

- Use consistent naming conventions for dashboards
- Include appropriate units and thresholds for metrics
- Organize panels logically for easy comparison
- Set appropriate refresh intervals based on metric volatility
- Include time range controls for historical analysis

## Troubleshooting

If dashboards don't appear:
1. Check Grafana logs: `kubectl logs -n monitoring deployment/grafana`
2. Verify ConfigMaps are correctly mounted
3. Check provisioning configuration at `/etc/grafana/provisioning/dashboards/dashboard.yaml`
4. Restart Grafana pod if configuration changes aren't picked up

## Accessing Dashboards

After deployment, access Grafana at:
- URL: http://<instance-ip>:30300/grafana
- Default credentials: admin/admin
- The dashboards should appear automatically in the "General" folder

## Debugging

### Lint and Validate Dashboard JSON
```bash
# Validate dashboard JSON syntax
python3 -c "import json; json.loads(open('k8s/04-grafana.yaml').read().split('scaleway-resources.json: |')[1].split('---')[0].strip())"

# Check for common issues
python3 -c "
import json
dashboard_json = open('k8s/04-grafana.yaml').read().split('scaleway-resources.json: |')[1].split('---')[0].strip()
data = json.loads(dashboard_json)
print('Dashboard title:', data.get('title'))
print('Dashboard UID:', data.get('uid'))
print('Number of panels:', len(data.get('panels', [])))
print('Has refresh interval:', 'refresh' in data)
"
```

### Check Dashboard Status
```bash
kubectl get configmaps -n monitoring grafana-dashboards
kubectl describe configmap -n monitoring grafana-dashboards
```

### View Grafana Logs
```bash
kubectl logs -n monitoring deployment/grafana -f
```

### Test Dashboard Provisioning
```bash
kubectl exec -it -n monitoring deployment/grafana -- ls /etc/grafana/provisioning/dashboards/
kubectl exec -it -n monitoring deployment/grafana -- cat /etc/grafana/provisioning/dashboards/dashboard.yaml
```

### Restart Grafana for Configuration Changes
```bash
kubectl rollout restart deployment/grafana -n monitoring
```

### Check Prometheus Data Source
```bash
kubectl exec -it -n monitoring deployment/grafana -- curl http://localhost:3000/api/datasources
```

### Verify Dashboard Updates
```bash
# After updating dashboards, verify they're loaded
kubectl exec -it -n monitoring deployment/grafana -- curl -s http://localhost:3000/api/search?query=& | jq '.[] | select(.type == "dash-db") | .title'
```

### View Grafana Logs
```bash
kubectl logs -n monitoring deployment/grafana -f
```

### Test Dashboard Provisioning
```bash
kubectl exec -it -n monitoring deployment/grafana -- ls /etc/grafana/provisioning/dashboards/
kubectl exec -it -n monitoring deployment/grafana -- cat /etc/grafana/provisioning/dashboards/dashboard.yaml
```

### Restart Grafana for Configuration Changes
```bash
kubectl rollout restart deployment/grafana -n monitoring
```

### Check Prometheus Data Source
```bash
kubectl exec -it -n monitoring deployment/grafana -- curl http://localhost:3000/api/datasources
```
