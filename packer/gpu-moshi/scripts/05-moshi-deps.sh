#!/bin/bash
# =============================================================================
# Moshi Demo Dependencies Installation
# =============================================================================
# Purpose: Install dependencies for Moshi AI model inference demo
# Includes: Python, transformers, audio tools, model caching
# =============================================================================

set -e

echo "=== [5/8] Moshi Demo Dependencies Installation ==="

export DEBIAN_FRONTEND=noninteractive

# Install Python and essential ML libraries
echo "Installing Python and ML dependencies..."
apt-get update -qq
apt-get install -y -qq \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-setuptools \
    python3-wheel \
    python3-numpy \
    python3-pyaudio \
    python3-scipy \
    libsndfile1 \
    ffmpeg \
    git-lfs

# Upgrade pip
echo "Upgrading pip..."
pip3 install --upgrade pip setuptools wheel --break-system-packages || \
    pip3 install --upgrade pip setuptools wheel

# Create Python virtual environment for Moshi
echo "Creating Python virtual environment for Moshi..."
mkdir -p /opt/moshi
python3 -m venv /opt/moshi/venv

# Activate virtual environment
source /opt/moshi/venv/bin/activate

# Install Moshi-specific dependencies
echo "Installing Moshi Python packages..."

# Core dependencies
pip3 install \
    torch==2.1.0 \
    torchaudio==2.1.0 \
    --index-url https://download.pytorch.org/whl/cu121 || \
pip3 install \
    torch \
    torchaudio

# Moshi and audio processing
pip3 install \
    transformers==4.35.0 \
    accelerate==0.25.0 \
    scipy==1.11.4 \
    librosa==0.10.1 \
    soundfile==0.12.1 \
    playsound==1.3.0 \
    requests==2.31.0 \
    tqdm==4.66.1 \
    numpy==1.24.3

# Moshi-specific packages
pip3 install \
    moshi-ml==0.1.1 || true  # May not be available, continue if fails

# Deactivate virtual environment
deactivate

# Install system audio tools
echo "Installing system audio tools..."
apt-get install -y -qq \
    sox \
    libsox-fmt-all \
    audacity || true

# Create Moshi model cache directory
echo "Creating Moshi model directories..."
mkdir -p /models/moshi
mkdir -p /models/huggingface
mkdir -p /models/cache

# Set permissions
chmod -R 755 /models
chown -R ubuntu:ubuntu /models 2>/dev/null || true

# Create Moshi startup script
cat > /usr/local/bin/moshi-init.sh << 'SCRIPT'
#!/bin/bash
# Moshi Model Initialization Script
# Pre-downloads minimal Moshi models for faster startup

set -e

MODELS_DIR="/models"
HF_HOME="/models/huggingface"

echo "=== Moshi Model Initialization ==="

# Set HuggingFace cache directory
export HF_HOME=$HF_HOME
export TRANSFORMERS_CACHE=$HF_HOME/cache
export HF_DATASETS_CACHE=$HF_HOME/cache

# Create cache directories
mkdir -p $HF_HOME
mkdir -p $HF_HOME/cache

echo "Models will be cached in: $MODELS_DIR"
echo "HuggingFace cache: $HF_HOME"

# Note: Actual model download happens at runtime
# This script prepares the environment

echo "=== Moshi Initialization Complete ==="
echo "To download models, run your workload once - they will be cached automatically."
SCRIPT
chmod +x /usr/local/bin/moshi-init.sh

# Create Moshi demo verification script
cat > /usr/local/bin/moshi-verify.sh << 'SCRIPT'
#!/bin/bash
# Moshi Demo Verification Script

echo "=== Moshi Demo Environment Verification ==="

echo "Python version:"
python3 --version

echo ""
echo "Python packages:"
source /opt/moshi/venv/bin/activate
pip list | grep -E "torch|transformers|librosa|scipy" || echo "Some packages may not be installed"
deactivate

echo ""
echo "Audio tools:"
which ffmpeg && ffmpeg -version | head -1 || echo "ffmpeg not found"
which play || which aplay || echo "No audio player found"

echo ""
echo "Model directories:"
ls -la /models/ || echo "Models directory not found"

echo ""
echo "GPU availability:"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || echo "GPU not available"

echo "=== Verification Complete ==="
SCRIPT
chmod +x /usr/local/bin/moshi-verify.sh

# Create Moshi test workload
cat > /usr/local/bin/moshi-gpu-test.sh << 'SCRIPT'
#!/bin/bash
# Moshi GPU Test Script
# Tests GPU availability for Moshi workloads

set -e

echo "=== Testing GPU with PyTorch ==="

source /opt/moshi/venv/bin/activate

python3 << 'PYTHON'
import torch
import sys

print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"GPU count: {torch.cuda.device_count()}")
    print(f"GPU name: {torch.cuda.get_device_name(0)}")
    print(f"GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
    
    # Test GPU computation
    print("\nTesting GPU computation...")
    x = torch.randn(1000, 1000).cuda()
    y = torch.randn(1000, 1000).cuda()
    z = torch.matmul(x, y)
    print("GPU computation: SUCCESS")
else:
    print("CUDA not available - GPU not accessible")
    sys.exit(1)

print("\nGPU test complete!")
PYTHON

deactivate

echo "=== GPU Test Complete ==="
SCRIPT
chmod +x /usr/local/bin/moshi-gpu-test.sh

# Clean up
echo "Cleaning up..."
apt-get clean -qq
rm -rf /var/lib/apt/lists/*

echo "=== Moshi Dependencies Installation Complete ==="
