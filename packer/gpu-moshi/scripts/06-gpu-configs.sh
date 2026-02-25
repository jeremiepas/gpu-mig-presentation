#!/bin/bash
# =============================================================================
# GPU Configuration - MIG & Time Slicing
# =============================================================================
# Purpose: Configure GPU for both MIG and Time Slicing modes
# Supports: Scaleway L4-24GB GPU
# =============================================================================

set -e

echo "=== [6/8] GPU Configuration (MIG & Time Slicing) ==="

# Detect GPU type
echo "Detecting GPU..."
GPU_MODEL=$(lspci | grep -i nvidia | head -1 || echo "Unknown")
echo "GPU: $GPU_MODEL"

# Check if nvidia-smi is available
if ! command -v nvidia-smi &>/dev/null; then
    echo "Warning: nvidia-smi not available (expected in build environment)"
    echo "Skipping GPU configuration..."
    
    # Create placeholder config files
    mkdir -p /etc/nvidia-gpu-config
    
    cat > /etc/nvidia-gpu-config/gpu-mode.conf << 'EOF'
# GPU Configuration Placeholder
# Actual GPU configuration will be applied at runtime
GPU_MODE=auto
EOF
    
    cat > /etc/nvidia-gpu-config/mig-config.yaml << 'EOF'
# MIG Configuration for L4 GPU
version: v1
mig:
  mode: "single"
  config:
    - gi: 1
      ci: 1
      memory: "6GB"
    - gi: 2
      ci: 1
      memory: "12GB"
    - gi: 3
      ci: 1
      memory: "24GB"
EOF
    
    cat > /etc/nvidia-gpu-config/timeslicing-config.yaml << 'EOF'
# Time Slicing Configuration
version: v1
sharing:
  timeSlicing:
    resources:
      - name: nvidia.com/gpu
        replicas: 4
EOF
    
    echo "Created placeholder GPU configurations"
    exit 0
fi

# Try to detect and configure GPU
echo "Attempting to configure GPU..."

# Check if GPU is accessible
if ! nvidia-smi &>/dev/null; then
    echo "Warning: Cannot access GPU (expected in build environment)"
    
    # Create placeholder configs
    mkdir -p /etc/nvidia-gpu-config
    
    cat > /etc/nvidia-gpu-config/mig-config.yaml << 'EOF'
# MIG Configuration for L4 GPU
# Applied via Kubernetes GPU Operator at runtime
version: v1
mig:
  mode: "single"
  config:
    - gi: 1
      ci: 1
      memory: "6GB"
    - gi: 2
      ci: 1
      memory: "12GB"
    - gi: 3
      ci: 1
      memory: "24GB"
EOF

    cat > /etc/nvidia-gpu-config/timeslicing-config.yaml << 'EOF'
# Time Slicing Configuration
# Applied via Kubernetes GPU Operator at runtime
version: v1
sharing:
  timeSlicing:
    resources:
      - name: nvidia.com/gpu
        replicas: 4
EOF

    echo "Created placeholder GPU configurations for runtime application"
    exit 0
fi

# GPU is available, configure it
echo "GPU detected, applying configuration..."

# Get GPU info
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "Unknown")
echo "Configuring GPU: $GPU_NAME"

# Create GPU config directory
mkdir -p /etc/nvidia-gpu-config

# Create MIG configuration for L4 GPU
# L4 supports: mig.1g.6gb, mig.2g.12gb, mig.3g.24gb
cat > /etc/nvidia-gpu-config/mig-config.yaml << 'EOF'
# MIG Configuration for L4 GPU (24GB)
# Supports multiple MIG instance configurations
version: v1
mig:
  mode: "single"  # "single" or "mixed"
  config:
    # Configuration 1: Single 3g.24gb (full GPU)
    - gi: 3
      ci: 1
      memory: "24GB"
    # Configuration 2: Two 2g.12gb
    - gi: 2
      ci: 1
      memory: "12GB"
    # Configuration 3: Four 1g.6gb
    - gi: 1
      ci: 1
      memory: "6GB"
EOF

# Create Time Slicing configuration
cat > /etc/nvidia-gpu-config/timeslicing-config.yaml << 'EOF'
# Time Slicing Configuration for L4 GPU
# Allows multiple pods to share GPU resources
version: v1
sharing:
  timeSlicing:
    resources:
      - name: nvidia.com/gpu
        # replicas: 2 = 2 pods per GPU
        # replicas: 4 = 4 pods per GPU (default)
        # replicas: 8 = 8 pods per GPU (aggressive)
        replicas: 4
EOF

# Create GPU mode selector script
cat > /usr/local/bin/gpu-mode.sh << 'SCRIPT'
#!/bin/bash
# GPU Mode Configuration Script
# Switches between MIG and Time Slicing modes

set -e

MODE=${1:-help}

GPU_CONFIG_DIR="/etc/nvidia-gpu-config"

usage() {
    echo "GPU Mode Configuration"
    echo ""
    echo "Usage: $0 <mode>"
    echo ""
    echo "Modes:"
    echo "  mig            - Enable MIG mode"
    echo "  timeslicing    - Enable Time Slicing mode"
    echo "  status         - Show current GPU configuration"
    echo "  help           - Show this help message"
    echo ""
    echo "Note: MIG requires specific GPU hardware support."
    echo "      Time Slicing works on all NVIDIA GPUs."
}

case $MODE in
    mig)
        echo "Switching to MIG mode..."
        
        # Check if MIG is supported
        if nvidia-smi mig -lgip &>/dev/null; then
            echo "MIG is supported on this GPU"
            
            # Apply MIG configuration
            nvidia-smi mig -Cgi 19,14,9 -Cci 19,14,9 2>/dev/null || true
            
            echo "MIG mode configured"
        else
            echo "Warning: MIG not supported on this GPU"
            echo "Falling back to Time Slicing..."
            $0 timeslicing
        fi
        ;;
        
    timeslicing)
        echo "Enabling Time Slicing mode..."
        
        # Disable MIG if enabled
        if nvidia-smi mig -lgip &>/dev/null; then
            nvidia-smi mig -Cgi 0 -Cci 0 2>/dev/null || true
        fi
        
        echo "Time Slicing mode configured"
        echo "Configure Kubernetes GPU operator for time slicing"
        ;;
        
    status)
        echo "=== GPU Configuration Status ==="
        
        echo ""
        echo "GPU Info:"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || echo "GPU not available"
        
        echo ""
        echo "MIG Status:"
        nvidia-smi mig 2>/dev/null || echo "MIG not available"
        
        echo ""
        echo "Current Mode:"
        if nvidia-smi --query-gpu=mig.mode --format=csv,noheader 2>/dev/null | grep -q "Enabled"; then
            echo "MIG: Enabled"
        else
            echo "Time Slicing (default)"
        fi
        ;;
        
    help|--help|-h)
        usage
        ;;
        
    *)
        echo "Unknown mode: $MODE"
        usage
        exit 1
        ;;
esac
SCRIPT

chmod +x /usr/local/bin/gpu-mode.sh

# Create GPU monitoring script
cat > /usr/local/bin/gpu-monitor.sh << 'SCRIPT'
#!/bin/bash
# GPU Monitoring Script
# Shows GPU utilization, memory, and compute usage

echo "=== GPU Monitor ==="
echo "Timestamp: $(date)"
echo ""

# GPU summary
echo "GPU Summary:"
nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw --format=csv,noheader,nounits || echo "GPU not available"

echo ""

# GPU processes
echo "GPU Processes:"
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader || echo "No GPU processes"

echo ""

# MIG devices (if available)
echo "MIG Devices:"
nvidia-smi mig -gi 2>/dev/null || echo "MIG not available"
SCRIPT

chmod +x /usr/local/bin/gpu-monitor.sh

# Enable NVIDIA GPU monitoring
systemctl enable nvidia-persistenced 2>/dev/null || true

# Create udev rules for GPU device access
cat > /etc/udev/rules.d/70-nvidia.rules << 'EOF'
# NVIDIA GPU device rules
KERNEL=="nvidia", RUN+="/bin/chmod a+rx /dev/nvidia"
KERNEL=="nvidia_uvm", RUN+="/bin/chmod a+rx /dev/nvidia_uvm"
KERNEL=="nvidia-modeset", RUN+="/bin/chmod a+rx /dev/nvidia-modeset"

# Create device nodes if missing
KERNEL=="nvidia", SUBSYSTEM=="misc", MODE="0666", OPTIONS+="static_node=nvidia"
KERNEL=="nvidia_uvm", SUBSYSTEM=="misc", MODE="0666", OPTIONS+="static_node=nvidia_uvm"
EOF

# Reload udev
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true

echo "=== GPU Configuration Complete ==="
echo ""
echo "To switch GPU modes:"
echo "  gpu-mode.sh timeslicing  # Enable Time Slicing"
echo "  gpu-mode.sh mig          # Enable MIG (if supported)"
echo "  gpu-mode.sh status       # Show current status"
