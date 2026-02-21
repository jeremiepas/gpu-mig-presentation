#cloud-config
ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFgYIuJ4GPLKOezfwkLVmcQEJQJblgbO4st51x1A67EL github-actions

runcmd:
  - curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true K3S_KUBECONFIG_MODE="644" sh -
  - systemctl enable k3s
  - systemctl start k3s
