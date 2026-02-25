#!/bin/bash
# Install NixOS package manager
set -e

echo "=== Step 2: Installing NixOS package manager ==="

# Install NixOS single-user (faster for images)
# Download and run the official installer
sh <(curl -L https://nixos.org/nix/install) --no-daemon --yes

# Source nix environment
if [ -f /root/.nix-profile/etc/profile.d/nix.sh ]; then
    . /root/.nix-profile/etc/profile.d/nix.sh
fi

# Add nix to profile for future logins
cat >> /root/.bashrc << 'EOF'
# NixOS
if [ -f /root/.nix-profile/etc/profile.d/nix.sh ]; then
    . /root/.nix-profile/etc/profile.d/nix.sh
fi
EOF

# Enable flakes and nix command
mkdir -p /root/.config/nix
cat > /root/.config/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
sandbox = false
EOF

# Install some basic nix packages
nix-env -iA nixpkgs.bash nixpkgs.gcc nixpkgs.make

echo "=== NixOS installed ==="
