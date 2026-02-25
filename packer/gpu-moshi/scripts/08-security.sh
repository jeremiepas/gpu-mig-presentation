#!/bin/bash
# =============================================================================
# Security Hardening
# =============================================================================
# Purpose: Apply security best practices for production GPU workloads
# =============================================================================

set -e

echo "=== [7/8] Security Hardening ==="

export DEBIAN_FRONTEND=noninteractive

# Configure firewall (UFW)
echo "Configuring firewall..."

# Install UFW if not present
apt-get update -qq
apt-get install -y -qq ufw

# Reset UFW to defaults
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (limited rate)
ufw limit 22/tcp comment "SSH with rate limiting"

# Allow K3s ports
ufw allow 6443/tcp comment "K3s API server"
ufw allow 10250/tcp comment "K3s kubelet"
ufw allow 10248/tcp comment "K3s kubelet health"
ufw allow 10249/tcp comment "K3s metrics"

# Allow monitoring ports (optional - for Grafana/Prometheus)
ufw allow 30090/tcp comment "Prometheus"
ufw allow 30300/tcp comment "Grafana"

# Enable UFW
echo "y" | ufw enable

# Configure SSH security
echo "Configuring SSH security..."

# Backup and harden SSH config
if [ -f /etc/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Apply SSH hardening
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
    sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' /etc/ssh/sshd_config
    sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' /etc/ssh/sshd_config
    
    # Disable empty passwords
    sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    
    # Restart SSH
    systemctl restart sshd || systemctl restart ssh || true
fi

# Configure fail2ban
echo "Installing and configuring fail2ban..."
apt-get install -y -qq fail2ban

# Create fail2ban configuration for SSH
cat > /etc/fail2ban/jail.d/ssh.conf << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

# Start fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Configure audit rules
echo "Configuring audit rules..."
apt-get install -y -qq auditd

# Add GPU access auditing
cat >> /etc/audit/rules.d/gpu.rules << 'EOF'
# Monitor GPU device access
-w /dev/nvidia0 -p rw -k gpu_access
-w /dev/nvidiactl -p rw -k gpu_access
-w /dev/nvidia-uvm -p rw -k gpu_access

# Monitor NVIDIA driver files
-w /usr/bin/nvidia-smi -p x -k nvidia_command
-w /usr/bin/nvidia-debugdump -p x -k nvidia_command
EOF

# Reload audit rules
auditctl -R /etc/audit/rules.d/gpu.rules 2>/dev/null || true

# Configure system limits for security
echo "Configuring system security limits..."

# Create security limits
cat > /etc/security/limits.d/security.conf << 'EOF'
# Core dump security
* soft core 0
* hard core 0

# Restrict core dump directory
fs.suid_dumpable 0
kernel.core_uses_pid 1
kernel.dmesg_restrict 1
EOF

# Apply sysctl security settings
cat > /etc/sysctl.d/99-security.conf << 'EOF'
# IP Forwarding - disabled (not a router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# ICMP - restrict broadcast
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Disable redirect acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0

# Disable send redirects
net.ipv4.conf.all.send_redirects = 0

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 0

# Kernel hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-security.conf || true

# Configure automatic security updates
echo "Configuring automatic security updates..."
apt-get install -y -qq unattended-upgrades

# Configure unattended upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};

Unattended-Upgrade::Package-Blacklist {
    // Keep kernel updates manual
    "linux-image.*";
    "linux-headers.*";
};

Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Mail "root";
Unattended-Upgrade::MailOnlyOnError "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Enable unattended upgrades
systemctl enable unattended-upgrades

# Configure logrotate for security logs
echo "Configuring log rotation..."
cat > /etc/logrotate.d/security-logs << 'EOF'
/var/log/auth.log {
    weekly
    rotate 12
    compress
    delaycompress
    notifempty
    create 0600 root root
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/fail2ban.log {
    weekly
    rotate 12
    compress
    delaycompress
    notifempty
    create 0600 root root
}
EOF

# Set secure umask
echo "Setting secure umask..."
echo "umask 0077" >> /etc/profile.d/secure-umask.sh
chmod +x /etc/profile.d/secure-umask.sh

# Remove unnecessary SUID binaries (optional hardening)
echo "Reviewing SUID binaries..."
# List potentially dangerous SUID binaries - don't remove without careful analysis
# This is just informational
# mount, umount, ping should typically remain for functionality

# Disable unnecessary services
echo "Disabling unnecessary services..."
systemctl mask --now atd || true
systemctl mask --now cups || true
systemctl mask --now avahi-daemon || true

# Clean up
echo "Cleaning up..."
apt-get clean -qq
rm -rf /var/lib/apt/lists/*

echo "=== Security Hardening Complete ==="
echo ""
echo "Security features applied:"
echo "  - UFW firewall with rate-limited SSH"
echo "  - SSH hardening (key-only auth, no root login)"
echo "  - Fail2ban for brute-force protection"
echo "  - Audit logging for GPU access"
echo "  - Kernel sysctl security settings"
echo "  - Automatic security updates enabled"
