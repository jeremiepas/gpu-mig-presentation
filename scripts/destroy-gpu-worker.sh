#!/bin/bash
# GPU Worker Destroy Script
# Usage: ./destroy-gpu-worker.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Check if credentials are loaded
if [ -z "$SCW_ACCESS_KEY" ] || [ -z "$SCW_SECRET_KEY" ]; then
    source credentials.env 2>/dev/null
fi

if [ -z "$SCW_ACCESS_KEY" ]; then
    echo -e "${RED}[ERROR]${NC} Credentials not loaded. Run: source credentials.env"
    exit 1
fi

log_info "Destroying GPU worker..."

# Check if GPU worker Terraform exists
if [ ! -d "terraform/environments/gpu-worker" ]; then
    log_warn "GPU worker Terraform directory not found. Nothing to destroy."
    exit 0
fi

# Destroy GPU worker
terraform -chdir=terraform/environments/gpu-worker destroy -auto-approve

log_info "GPU worker destroyed successfully"
