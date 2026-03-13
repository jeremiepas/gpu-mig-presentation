# ArgoCD Implementation Checklist

This document tracks the implementation status of ArgoCD deployment across NixOS K3s and Standard K8s clusters for the GPU MIG Presentation project.

---

## Completed Tasks

### Documentation

- [x] Created comprehensive deployment plan (PLAN.md)
- [x] Documented architecture overview with diagrams
- [x] Documented security considerations and RBAC policies
- [x] Created access instructions for UI and CLI
- [x] Documented troubleshooting steps

### NixOS K3s - Phase 1

- [x] Created namespace manifest (`nixos/argocd/00-namespace.yaml`)
- [x] Created core components manifest (`nixos/argocd/01-argocd-install.yaml`)
  - [x] ConfigMap for ArgoCD configuration
  - [x] ConfigMap for RBAC policies
  - [x] Deployment for ArgoCD server
  - [x] Deployment for ArgoCD repo-server
  - [x] Deployment for ArgoCD application-controller
  - [x] StatefulSet for Redis
  - [x] Services for all components
  - [x] ClusterRole and ClusterRoleBinding
- [x] Created ingress manifest (`nixos/argocd/02-ingress.yaml`)
  - [x] Traefik Ingress resource
  - [x] Middleware for headers
  - [x] TLS configuration placeholder
- [x] Created applications manifest (`nixos/argocd/03-applications.yaml`)
  - [x] Application: namespaces
  - [x] Application: nvidia-runtimeclass
  - [x] Application: gpu-operator
  - [x] Application: gpu-config
  - [x] Application: monitoring-stack
  - [x] Application: moshi-setup
  - [x] Application: moshi-inference-timeslicing
  - [x] Application: moshi-inference-mig
  - [x] Application: ingress-routes
  - [x] Application: billing-exporter
  - [x] AppProject definition
- [x] Created Infisical secrets manifest (`nixos/argocd/04-infisical-secrets.yaml`)
  - [x] External Secrets Operator namespace
  - [x] ClusterSecretStore configuration
  - [x] Auth secret template
  - [x] ExternalSecret for admin password
  - [x] ExternalSecret for git credentials

### Standard K8s - Phase 2

- [x] Created namespace manifest (`k8s/argocd/00-namespace.yaml`)
- [x] Created core components manifest (`k8s/argocd/01-argocd-install.yaml`)
  - [x] LoadBalancer service configuration
  - [x] Scaleway-specific annotations
- [x] Created ingress manifest (`k8s/argocd/02-ingress.yaml`)
- [x] Created applications manifest (`k8s/argocd/03-applications.yaml`)
- [x] Created Infisical secrets manifest (`k8s/argocd/04-infisical-secrets.yaml`)

### Existing ArgoCD Applications

- [x] Reviewed existing `argo-app/applications.yaml`
- [x] Verified application structure matches deployment plan
- [x] Documented application dependencies

---

## In Progress

### NixOS K3s Deployment

- [ ] Deploy namespace to NixOS K3s cluster
- [ ] Install ArgoCD core components
- [ ] Configure Traefik ingress
- [ ] Verify pods are running
- [ ] Test UI access via `https://<domain>/argocd`

### Configuration Review

- [ ] Review and update repository URLs in applications
- [ ] Verify all paths match actual file locations
- [ ] Validate resource limits and requests
- [ ] Confirm ingress domain names

---

## Pending Tasks

### High Priority

- [ ] **Update repository URLs** in all Application manifests
  - Replace `YOUR_ORG/gpu-mig-presentation` with actual organization
  - Verify all `targetRevision` values
  - Update in both NixOS and K8s application files

- [ ] **Configure domain names** in ingress manifests
  - NixOS: Update `montech.montech.mylab` if changed
  - Standard K8s: Update `4edcb867-7b4e-4890-b3d6-7912075f20d8.pub.instances.scw.cloud`

- [ ] **Set up Infisical credentials** (if using)
  - Obtain client ID and secret from Infisical
  - Configure secrets in cluster
  - Test External Secrets Operator integration

- [ ] **Verify file paths** in Application manifests
  - Ensure all referenced files exist in repository
  - Check path patterns for directory-based applications
  - Validate include/exclude patterns

### Medium Priority

- [ ] **Deploy to NixOS K3s cluster**
  - Run deployment commands in order
  - Monitor pod startup and health
  - Verify all services are accessible

- [ ] **Deploy to Standard K8s cluster**
  - Wait for LoadBalancer provisioning
  - Configure DNS if needed
  - Verify external access

- [ ] **Create AppProject for organization**
  - Define resource constraints
  - Set up source repository restrictions
  - Configure destination namespace policies

- [ ] **Configure automated sync policies**
  - Review prune settings
  - Configure self-heal options
  - Set up sync windows (optional)

### Low Priority

- [ ] **Enable cert-manager integration**
  - Configure ClusterIssuer
  - Update ingress TLS sections
  - Test HTTPS access

- [ ] **Set up Git webhooks**
  - Configure GitHub/GitLab webhook URL
  - Add webhook secret
  - Test automatic sync

- [ ] **Configure notifications**
  - Set up Slack integration
  - Configure email notifications
  - Define notification triggers

- [ ] **Create team RBAC policies**
  - Define read-only role
  - Create admin role
  - Set up project-level permissions

- [ ] **Add ArgoCD to monitoring**
  - Create Grafana dashboard for ArgoCD
  - Configure Prometheus scraping
  - Set up alerts for sync failures

- [ ] **Document operational procedures**
  - Create runbook for common issues
  - Document rollback procedures
  - Write team onboarding guide

---

## Testing Phase

### Pre-Deployment Validation

- [ ] Run `kubectl apply --dry-run=client` on all manifests
- [ ] Validate YAML syntax for all files
- [ ] Check for missing or incorrect resource references
- [ ] Verify ConfigMap data formatting

### NixOS K3s Testing

- [ ] **Namespace creation**
  - [ ] Verify namespace exists
  - [ ] Check labels are applied
  - [ ] Confirm service account creation

- [ ] **Core components deployment**
  - [ ] All pods running and ready
  - [ ] Services have endpoints
  - [ ] ConfigMaps are configured
  - [ ] RBAC resources created

- [ ] **Ingress configuration**
  - [ ] Ingress resource created
  - [ ] Traefik routes configured
  - [ ] Path-based routing works
  - [ ] TLS certificates valid (if configured)

- [ ] **UI Access**
  - [ ] Can access `https://<domain>/argocd`
  - [ ] Login with admin credentials works
  - [ ] Dashboard loads without errors
  - [ ] Applications visible in UI

- [ ] **CLI Access**
  - [ ] ArgoCD CLI can login
  - [ ] Can list applications
  - [ ] Can view application status
  - [ ] Sync commands work

### Standard K8s Testing

- [ ] **LoadBalancer provisioning**
  - [ ] External IP assigned
  - [ ] Health checks passing
  - [ ] Scaleway LB created

- [ ] **Ingress configuration**
  - [ ] Ingress resource created
  - [ ] Path-based routing works
  - [ ] DNS resolution successful

- [ ] **Application sync**
  - [ ] All applications created
  - [ ] Sync status healthy
  - [ ] Resources deployed correctly

### Application Testing

- [ ] **namespaces application**
  - [ ] Syncs successfully
  - [ ] Creates all required namespaces

- [ ] **gpu-operator application**
  - [ ] GPU operator pods running
  - [ ] Nodes labeled correctly

- [ ] **monitoring-stack application**
  - [ ] Prometheus accessible
  - [ ] Grafana dashboards available
  - [ ] Metrics collecting

- [ ] **moshi applications**
  - [ ] Moshi pods deploy
  - [ ] GPU resources allocated
  - [ ] Inference workloads run

### Integration Testing

- [ ] **Infisical integration** (if enabled)
  - [ ] External Secrets Operator running
  - [ ] Secrets sync from Infisical
  - [ ] ArgoCD uses external secrets

- [ ] **GitOps workflow**
  - [ ] Commit triggers sync
  - [ ] Changes propagate to cluster
  - [ ] Rollback works correctly

---

## Documentation

### Technical Documentation

- [ ] **Deployment Guide**
  - [ ] Step-by-step deployment instructions
  - [ ] Command reference
  - [ ] Troubleshooting section

- [ ] **Operations Guide**
  - [ ] Daily operations checklist
  - [ ] Monitoring and alerting
  - [ ] Backup and restore procedures

- [ ] **Security Documentation**
  - [ ] RBAC configuration details
  - [ ] Secret management procedures
  - [ ] Security hardening checklist

### User Documentation

- [ ] **User Guide**
  - [ ] Accessing ArgoCD UI
  - [ ] Viewing application status
  - [ ] Basic troubleshooting

- [ ] **Developer Guide**
  - [ ] Adding new applications
  - [ ] Updating existing applications
  - [ ] Sync policies and options

- [ ] **Administrator Guide**
  - [ ] Cluster management
  - [ ] User management
  - [ ] Maintenance procedures

### README Updates

- [ ] Update main README.md with ArgoCD information
- [ ] Add ArgoCD section to AGENTS.md
- [ ] Create QUICKSTART.md for ArgoCD access
- [ ] Update architecture diagrams

---

## Sign-off Checklist

### Before Production

- [ ] All high priority tasks completed
- [ ] Testing phase passed
- [ ] Security review completed
- [ ] Documentation finalized
- [ ] Team training completed
- [ ] Rollback plan documented

### Post-Deployment

- [ ] Monitoring dashboards verified
- [ ] Alerts configured and tested
- [ ] Backup jobs scheduled
- [ ] Runbook accessible to team
- [ ] On-call rotation updated
- [ ] Incident response procedures reviewed

---

## Notes

### Blockers

*Document any blockers here as they arise*

- None currently identified

### Dependencies

- External Secrets Operator must be installed before Infisical integration
- Cert-manager should be configured before enabling TLS
- Git repository must be accessible from cluster networks

### Configuration Changes

*Track any configuration changes made during implementation*

| Date | Change | Reason | Approved By |
|------|--------|--------|-------------|
| - | - | - | - |

### Lessons Learned

*Document lessons learned during implementation*

| Date | Lesson | Impact |
|------|--------|--------|
| - | - | - |

---

## Quick Reference

### Deployment Commands

```bash
# NixOS K3s
export KUBECONFIG="$HOME/.kube/config-k3s-remote"
kubectl apply -f nixos/argocd/00-namespace.yaml
kubectl apply -f nixos/argocd/01-argocd-install.yaml
kubectl apply -f nixos/argocd/02-ingress.yaml
kubectl apply -f nixos/argocd/03-applications.yaml

# Standard K8s
export KUBECONFIG="$HOME/.kube/config"
kubectl apply -f k8s/argocd/00-namespace.yaml
kubectl apply -f k8s/argocd/01-argocd-install.yaml
kubectl apply -f k8s/argocd/02-ingress.yaml
kubectl apply -f k8s/argocd/03-applications.yaml
```

### Verification Commands

```bash
# Check pods
kubectl get pods -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# List applications
argocd app list

# Port forward for local access
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

### File Locations

| Component | NixOS Path | K8s Path |
|-----------|------------|----------|
| Namespace | `nixos/argocd/00-namespace.yaml` | `k8s/argocd/00-namespace.yaml` |
| Core Components | `nixos/argocd/01-argocd-install.yaml` | `k8s/argocd/01-argocd-install.yaml` |
| Ingress | `nixos/argocd/02-ingress.yaml` | `k8s/argocd/02-ingress.yaml` |
| Applications | `nixos/argocd/03-applications.yaml` | `k8s/argocd/03-applications.yaml` |
| Secrets | `nixos/argocd/04-infisical-secrets.yaml` | `k8s/argocd/04-infisical-secrets.yaml` |

---

*Last Updated: 2025-02-27*
*Status: In Progress*
