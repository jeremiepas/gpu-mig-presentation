#!/bin/bash
# Backup script for current Terraform state and Kubernetes manifests
# Requirements: 17.1, 17.2

set -e

# Configuration
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
TERRAFORM_ENVS=("dev" "prod" "local")
K8S_DIR="k8s"

echo "=== Backup Current State ==="
echo "Backup directory: ${BACKUP_DIR}"
echo ""

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Backup Terraform state files
echo "Backing up Terraform state files..."
for env in "${TERRAFORM_ENVS[@]}"; do
  env_path="terraform/environments/${env}"
  
  if [ -d "${env_path}" ]; then
    echo "  - Backing up ${env} environment..."
    mkdir -p "${BACKUP_DIR}/terraform/${env}"
    
    # Backup state files
    if [ -f "${env_path}/terraform.tfstate" ]; then
      cp "${env_path}/terraform.tfstate" "${BACKUP_DIR}/terraform/${env}/"
      echo "    ✓ terraform.tfstate"
    fi
    
    if [ -f "${env_path}/terraform.tfstate.backup" ]; then
      cp "${env_path}/terraform.tfstate.backup" "${BACKUP_DIR}/terraform/${env}/"
      echo "    ✓ terraform.tfstate.backup"
    fi
    
    # Backup tfvars if exists
    if [ -f "${env_path}/terraform.tfvars" ]; then
      cp "${env_path}/terraform.tfvars" "${BACKUP_DIR}/terraform/${env}/"
      echo "    ✓ terraform.tfvars"
    fi
  else
    echo "  - Skipping ${env} (directory not found)"
  fi
done

# Backup Kubernetes manifests
echo ""
echo "Backing up Kubernetes manifests..."
if [ -d "${K8S_DIR}" ]; then
  mkdir -p "${BACKUP_DIR}/k8s"
  
  # Backup all YAML files in k8s root
  for file in ${K8S_DIR}/*.yaml; do
    if [ -f "$file" ]; then
      cp "$file" "${BACKUP_DIR}/k8s/"
      echo "  ✓ $(basename $file)"
    fi
  done
  
  # Backup subdirectories if they exist
  if [ -d "${K8S_DIR}/argocd" ]; then
    cp -r "${K8S_DIR}/argocd" "${BACKUP_DIR}/k8s/"
    echo "  ✓ argocd/ directory"
  fi
  
  if [ -d "${K8S_DIR}/common" ]; then
    cp -r "${K8S_DIR}/common" "${BACKUP_DIR}/k8s/"
    echo "  ✓ common/ directory"
  fi
  
  if [ -d "${K8S_DIR}/environments" ]; then
    cp -r "${K8S_DIR}/environments" "${BACKUP_DIR}/k8s/"
    echo "  ✓ environments/ directory"
  fi
else
  echo "  - k8s directory not found"
fi

# Backup ArgoCD applications from cluster (if kubectl is available)
echo ""
echo "Backing up ArgoCD applications from cluster..."
if command -v kubectl &> /dev/null; then
  mkdir -p "${BACKUP_DIR}/argocd-cluster"
  
  # Check if argocd namespace exists
  if kubectl get namespace argocd &> /dev/null; then
    echo "  - Exporting ArgoCD applications..."
    kubectl get applications -n argocd -o yaml > "${BACKUP_DIR}/argocd-cluster/applications.yaml" 2>/dev/null || echo "    ⚠ No applications found"
    
    echo "  - Exporting ArgoCD projects..."
    kubectl get appprojects -n argocd -o yaml > "${BACKUP_DIR}/argocd-cluster/appprojects.yaml" 2>/dev/null || echo "    ⚠ No projects found"
    
    echo "  ✓ ArgoCD resources exported"
  else
    echo "  - ArgoCD namespace not found (skipping cluster backup)"
  fi
else
  echo "  - kubectl not available (skipping cluster backup)"
fi

# Create backup manifest
echo ""
echo "Creating backup manifest..."
cat > "${BACKUP_DIR}/MANIFEST.txt" << EOF
Backup created: $(date)
Backup directory: ${BACKUP_DIR}

Contents:
- Terraform state files from: ${TERRAFORM_ENVS[@]}
- Kubernetes manifests from: ${K8S_DIR}/
- ArgoCD applications from cluster (if available)

To restore:
  ./scripts/rollback-migration.sh ${BACKUP_DIR}
EOF

echo "  ✓ MANIFEST.txt created"

# Create tarball
echo ""
echo "Creating tarball..."
TARBALL="backups/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "${TARBALL}" -C "$(dirname ${BACKUP_DIR})" "$(basename ${BACKUP_DIR})"
echo "  ✓ ${TARBALL}"

# Summary
echo ""
echo "=== Backup Complete ==="
echo "Backup location: ${BACKUP_DIR}"
echo "Tarball: ${TARBALL}"
echo ""
echo "To restore this backup:"
echo "  ./scripts/rollback-migration.sh ${BACKUP_DIR}"
