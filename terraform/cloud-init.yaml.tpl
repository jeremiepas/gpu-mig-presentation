#cloud-config
ssh_authorized_keys:
  - ${ssh_public_key}

runcmd:
  - [sh, -c, "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE='644' sh -"]
  - systemctl enable k3s
  - systemctl start k3s
