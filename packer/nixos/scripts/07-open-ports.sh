#!/bin/bash
# Open all ports - security not a concern for this demo
set -e

echo "=== Step 7: Opening all ports ==="

export DEBIAN_FRONTEND=noninteractive

# Disable firewall completely
echo "Disabling firewall..."
systemctl stop ufw || true
systemctl disable ufw || true
systemctl mask ufw || true

# Flush all iptables rules
echo "Flushing iptables rules..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Set default policies to ACCEPT
echo "Setting default policies to ACCEPT..."
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Allow all traffic
echo "Allowing all traffic..."
iptables -A INPUT -j ACCEPT
iptables -A FORWARD -j ACCEPT
iptables -A OUTPUT -j ACCEPT

# Allow all IPv6
ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -F

# Make iptables rules persistent (if iptables-persistent is installed)
# Create a script to restore rules on boot that accepts all
mkdir -p /etc/network/if-pre-up.d
cat > /etc/network/if-pre-up.d/iptables << 'EOF'
#!/bin/sh
/sbin/iptables -P INPUT ACCEPT
/sbin/iptables -P FORWARD ACCEPT
/sbin/iptables -P OUTPUT ACCEPT
EOF
chmod +x /etc/network/if-pre-up.d/iptables

# Disable SELinux/AppArmor
echo "Disabling AppArmor..."
systemctl stop apparmor || true
systemctl disable apparmor || true

# Disable TCP SYN cookies
echo "Disabling TCP SYN cookies..."
echo 0 > /proc/sys/net/ipv4/tcp_syncookies || true

# Disable IP routing verification
echo "Disabling IP routing verification..."
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter || true
echo 0 > /proc/sys/net/ipv4/conf/default/rp_filter || true

# Allow all ICMP
echo "Allowing all ICMP..."
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts || true

# Allow all connections
echo "Allowing all connections..."
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse || true

# Open all common ports in use
echo "Opening all common ports..."

# Kubernetes ports
# K3s API Server: 6443
# K3s Agent: 10250
# NodePort range: 30000-32767

# Docker ports
# Docker: 2375, 2376
# Portainer: 9000, 9443

# Monitoring
# Prometheus: 30090
# Grafana: 30300
# Node Exporter: 9100

# SSH
# SSH: 22

# Create a service to ensure all ports are open on boot
cat > /etc/systemd/system/open-ports.service << 'EOF'
[Unit]
Description=Open all ports on boot
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'iptables -F; iptables -X; iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable open-ports.service || true

echo "=== All ports opened ==="
