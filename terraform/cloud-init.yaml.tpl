#cloud-config
ssh_authorized_keys:
  - ${ssh_public_key}

runcmd:
  - curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true K3S_KUBECONFIG_MODE="644" sh || true
  - systemctl enable k3s || true
  - systemctl start k3s || true
