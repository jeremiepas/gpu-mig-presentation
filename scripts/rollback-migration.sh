#!/bin/bash
# Rollback script for migration
# Restores Terraform state and Kubernetes manifests from backup
# Requirement: 17.4

set -e

# Check if backup directory is provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <backup-directory>"
  echo ""
  echo "Example:"
  echo "  $0 backups/20240313_120000"
  echo ""
  echo "Available backups:"
  ls -1d backups/*/ 2>/dev/null || echo "  No backups found"
  exit 1
fi

BACKUP_DIR="$1"

# Validate backup directory
if [ ! -d "${BACKUP_DIR}" ]; then
  echo "Error: Backup directory not found: ${BACKUP_DIR}"
  exit 1
fi

echo "=== Rollback Migration ==="
echo "Backup directory: ${BACKUP_DIR}"
echo ""

# Confirmation prompt
read -p "This will restore files from backup. Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Rollback cancelled"
  exit 0
fi

# Restore Terraform state files
echo ""
echo "Restoring Terraform state files..."
if [ -d "${BACKUP_DIR}/terraform" ]; then
  for env_backup in ${BACKUP_DIR}/terraform/*; do
    if [ -d "$env_backup" ]; then
      env_name=$(basename "$env_backup")
      env_path="terraform/environments/${env_name}"
      
      echo "  - Restoring ${env_name} environment..."
      mkdir -p "${env_path}"
      
      # Restore state files
      if [ -f "${env_backup}/terraform.tfstate" ]; then
        cp "${env_backup}/terraform.tfstate" "${env_path}/"
        echo "    ✓ terraform.tfstate"
      fi
      
      if [ -f "${env_backup}/terraform.tfstate.backup" ]; then
        cp "${env_backup}/terraform.tfstate.backup" "${env_path}/"
        echo "    ✓ terraform.tfstate.backup"
      fi
      
      # Restore tfvars if exists
      if [ -f "${env_backup}/terraform.tfvars" ]; then
        cp "${env_backup}/terraform.tfvars" "${env_path}/"
        echo "    ✓ terraform.tfvars"
      fi
    fi
  done
else
  echo "  - No Terraform backups found"
fi

# Restore Kubernetes manifests
echo ""
echo "Restoring Kubernetes manifests..."
if [ -d "${BACKUP_DIR}/k8s" ]; then
  # Create backup of current state before restoring
  CURRENT_BACKUP="backups/pre-rollback-$(date +%Y%m%d_%H%M%S)"
  mkdir -p "${CURRENT_BACKUP}"
  
  if [ -d "k8s" ]; then
    echo "  - Creating backup of current k8s/ directory..."
    cp -r k8s "${CURRENT_BACKUP}/"
    echo "    ✓ Current state backed up to ${CURRENT_BACKUP}"
  fi
  
  # Restore manifests
  echo "  - Restoring k8s/ directory..."
  
  # Restore root YAML files
  for file in ${BACKUP_DIR}/k8s/*.yaml; do
    if [ -f "$file" ]; then
      cp "$file" "k8s/"
      echo "    ✓ $(basename $file)"
    fi
  done
  
  # Restore subdirectories
  if [ -d "${BACKUP_DIR}/k8s/argocd" ]; then
    rm -rf "k8s/argocd"
    cp -r "${BACKUP_DIR}/k8s/argocd" "k8s/"
    echo "    ✓ argocd/ directory"
  fi
  
  if [ -d "${BACKUP_DIR}/k8s/common" ]; then
    rm -rf "k8s/common"
    cp -r "${BACKUP_DIR}/k8s/common" "k8s/"
    echo "    ✓ common/ directory"
  fi
  
  if [ -d "${BACKUP_DIR}/k8s/environments" ]; then
    rm -rf "k8s/environments"
    cp -r "${BACKUP_DIR}/k8s/environments" "k8s/"
    echo "    ✓ environments/ directory"
  fi
else
  echo "  - No Kubernetes manifest backups found"
fi

# Restore ArgoCD applications to cluster (if kubectl is available)
echo ""
echo "Restoring ArgoCD applications to cluster..."
if command -v kubectl &> /dev/null; then
  if [ -d "${BACKUP_DIR}/argocd-cluster" ]; then
    # Check if argocd namespace exists
    if kubectl get namespace argocd &> /dev/null; then
      echo "  - Restoring ArgoCD applications..."
      
      if [ -f "${BACKUP_DIR}/argocd-cluster/applications.yaml" ]; then
        kubectl apply -f "${BACKUP_DIR}/argocd-cluster/applications.yaml"
        echo "    ✓ Applications restored"
      fi
      
      if [ -f "${BACKUP_DIR}/argocd-cluster/appprojects.yaml" ]; then
        kubectl apply -f "${BACKUP_DIR}/argocd-cluster/appprojects.yaml"
        echo "    ✓ Projects restored"
      fi
    else
      echo "  - ArgoCD namespace not found (skipping cluster restore)"
    fi
  else
    echo "  - No ArgoCD cluster backups found"
  fi
else
  echo "  - kubectl not available (skipping cluster restore)"
fi

# Summary
echo ""
echo "=== Rollback Complete ==="
echo "Restored from: ${BACKUP_DIR}"
echo ""
echo "Next steps:"
echo "  1. Verify Terraform state: terraform -chdir=terraform/environments/<env> show"
echo "  2. Verify Kubernetes manifests: ls -la k8s/"
echo "  3. If needed, re-run: terraform init && terraform plan"
echo ""
echo "Note: Current state was backed up to ${CURRENT_BACKUP} (if k8s/ existed)"
