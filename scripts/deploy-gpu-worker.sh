#!/bin/bash
# GPU Worker On-Demand Deployment Script
# Usage: ./deploy-gpu-worker.sh [timeout-minutes]
# Default timeout: 25 minutes of GPU inactivity

TIMEOUT_MINUTES=${1:-25}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if credentials are loaded
if [ -z "$SCW_ACCESS_KEY" ] || [ -z "$SCW_SECRET_KEY" ]; then
    log_error "Credentials not loaded. Run: source credentials.env"
    exit 1
fi

# Source credentials
source credentials.env 2>/dev/null

log_info "Deploying GPU worker with ${TIMEOUT_MINUTES} minute auto-shutdown..."

# Check if GPU worker already exists
WORKER_IP=$(terraform -chdir=terraform/environments/gpu-worker output instance_ip 2>/dev/null || echo "")

if [ -n "$WORKER_IP" ]; then
    log_warn "GPU worker already exists at $WORKER_IP"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Using existing worker at $WORKER_IP"
    else
        log_info "Destroying existing worker..."
        terraform -chdir=terraform/environments/gpu-worker destroy -auto-approve
    fi
fi

# Initialize and deploy GPU worker
log_info "Initializing GPU worker Terraform..."
terraform -chdir=terraform/environments/gpu-worker init

log_info "Planning GPU worker deployment..."
terraform -chdir=terraform/environments/gpu-worker plan -out=tfplan

log_info "Deploying GPU worker..."
terraform -chdir=terraform/environments/gpu-worker apply -auto-approve tfplan

# Get worker IP
WORKER_IP=$(terraform -chdir=terraform/environments/gpu-worker output instance_ip)

log_info "GPU Worker deployed at: $WORKER_IP"
log_info "Timeout: ${TIMEOUT_MINUTES} minutes of GPU inactivity"
log_info ""
log_info "To connect:"
echo "  ssh -i ssh_key ubuntu@$WORKER_IP"
echo ""
log_info "To destroy manually:"
echo "  terraform -chdir=terraform/environments/gpu-worker destroy"
