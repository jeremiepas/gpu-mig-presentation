#!/bin/bash
# Manifest classification script
# Classifies Kubernetes manifests as common or environment-specific
# Requirements: 17.3, 8.1, 8.2, 8.3, 8.4, 8.5

set -e

# Configuration
K8S_DIR="k8s"
COMMON_DIR="${K8S_DIR}/common"
PROD_DIR="${K8S_DIR}/environments/prod"
PREPROD_DIR="${K8S_DIR}/environments/pre-prod"
HOMELAB_DIR="${K8S_DIR}/environments/homelab"
REPORT_FILE="manifest-classification-report.txt"

# Common manifest patterns (deployed across all environments)
COMMON_PATTERNS=(
  "00-namespaces.yaml"
  "00-nvidia-runtimeclass.yaml"
  "01-gpu-operator.yaml"
  "03-prometheus.yaml"
  "04-grafana.yaml"
  "04-grafana-datasources.yaml"
  "05-moshi-setup.yaml"
  "09-node-exporter.yaml"
  "12-kube-state-metrics.yaml"
  "14-dcgm-exporter.yaml"
)

# Environment-specific patterns
PROD_PATTERNS=(
  "02-mig-config.yaml"
  "*-mig.yaml"
  "ingress-prod.yaml"
  "resource-quotas.yaml"
  "network-policies.yaml"
)

PREPROD_PATTERNS=(
  "02-timeslicing-config.yaml"
  "*-timeslicing.yaml"
  "ingress-preprod.yaml"
  "resource-quotas.yaml"
)

HOMELAB_PATTERNS=(
  "02-timeslicing-config.yaml"
  "*-timeslicing.yaml"
  "local-storage.yaml"
  "ingress-homelab.yaml"
  "ingress-local.yaml"
  "reduced-resources.yaml"
)

echo "=== Kubernetes Manifest Classification ==="
echo ""

# Initialize report
cat > "${REPORT_FILE}" << EOF
Kubernetes Manifest Classification Report
Generated: $(date)

EOF

# Create target directories
mkdir -p "${COMMON_DIR}"
mkdir -p "${PROD_DIR}"
mkdir -p "${PREPROD_DIR}"
mkdir -p "${HOMELAB_DIR}"

# Function to check if file matches pattern
matches_pattern() {
  local file="$1"
  local pattern="$2"
  
  case "$file" in
    $pattern) return 0 ;;
    *) return 1 ;;
  esac
}

# Function to classify a manifest
classify_manifest() {
  local file="$1"
  local basename=$(basename "$file")
  local classified=false
  
  # Check common patterns
  for pattern in "${COMMON_PATTERNS[@]}"; do
    if matches_pattern "$basename" "$pattern"; then
      echo "  ✓ $basename → common/"
      echo "COMMON: $basename" >> "${REPORT_FILE}"
      
      # Copy to common directory if not already there
      if [ "$file" != "${COMMON_DIR}/${basename}" ]; then
        cp "$file" "${COMMON_DIR}/"
      fi
      
      classified=true
      return 0
    fi
  done
  
  # Check prod patterns
  for pattern in "${PROD_PATTERNS[@]}"; do
    if matches_pattern "$basename" "$pattern"; then
      echo "  ✓ $basename → environments/prod/"
      echo "PROD: $basename" >> "${REPORT_FILE}"
      
      if [ "$file" != "${PROD_DIR}/${basename}" ]; then
        cp "$file" "${PROD_DIR}/"
      fi
      
      classified=true
      break
    fi
  done
  
  # Check pre-prod patterns
  for pattern in "${PREPROD_PATTERNS[@]}"; do
    if matches_pattern "$basename" "$pattern"; then
      echo "  ✓ $basename → environments/pre-prod/"
      echo "PRE-PROD: $basename" >> "${REPORT_FILE}"
      
      if [ "$file" != "${PREPROD_DIR}/${basename}" ]; then
        cp "$file" "${PREPROD_DIR}/"
      fi
      
      classified=true
      break
    fi
  done
  
  # Check homelab patterns
  for pattern in "${HOMELAB_PATTERNS[@]}"; do
    if matches_pattern "$basename" "$pattern"; then
      echo "  ✓ $basename → environments/homelab/"
      echo "HOMELAB: $basename" >> "${REPORT_FILE}"
      
      if [ "$file" != "${HOMELAB_DIR}/${basename}" ]; then
        cp "$file" "${HOMELAB_DIR}/"
      fi
      
      classified=true
      break
    fi
  done
  
  if [ "$classified" = false ]; then
    echo "  ⚠ $basename → UNCLASSIFIED"
    echo "UNCLASSIFIED: $basename" >> "${REPORT_FILE}"
  fi
}

# Classify manifests in k8s root directory
echo "Classifying manifests in ${K8S_DIR}/..."
if [ -d "${K8S_DIR}" ]; then
  for file in ${K8S_DIR}/*.yaml; do
    if [ -f "$file" ]; then
      classify_manifest "$file"
    fi
  done
else
  echo "  - ${K8S_DIR} directory not found"
fi

# Summary
echo ""
echo "=== Classification Summary ==="
echo ""

common_count=$(grep -c "^COMMON:" "${REPORT_FILE}" || echo "0")
prod_count=$(grep -c "^PROD:" "${REPORT_FILE}" || echo "0")
preprod_count=$(grep -c "^PRE-PROD:" "${REPORT_FILE}" || echo "0")
homelab_count=$(grep -c "^HOMELAB:" "${REPORT_FILE}" || echo "0")
unclassified_count=$(grep -c "^UNCLASSIFIED:" "${REPORT_FILE}" || echo "0")

echo "Common manifests:        ${common_count}"
echo "Prod manifests:          ${prod_count}"
echo "Pre-prod manifests:      ${preprod_count}"
echo "Homelab manifests:       ${homelab_count}"
echo "Unclassified manifests:  ${unclassified_count}"
echo ""

cat >> "${REPORT_FILE}" << EOF

Summary:
--------
Common manifests:        ${common_count}
Prod manifests:          ${prod_count}
Pre-prod manifests:      ${preprod_count}
Homelab manifests:       ${homelab_count}
Unclassified manifests:  ${unclassified_count}

Target directories:
- ${COMMON_DIR}/
- ${PROD_DIR}/
- ${PREPROD_DIR}/
- ${HOMELAB_DIR}/
EOF

echo "Report saved to: ${REPORT_FILE}"
echo ""

if [ "$unclassified_count" -gt 0 ]; then
  echo "⚠ Warning: ${unclassified_count} manifests could not be classified"
  echo "   Review ${REPORT_FILE} for details"
  exit 1
fi

echo "✓ All manifests classified successfully"
