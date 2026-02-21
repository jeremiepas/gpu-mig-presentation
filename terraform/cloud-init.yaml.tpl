#cloud-config
users:
  - name: ubuntu
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFgYIuJ4GPLKOezfwkLVmcQEJQJblgbO4st51x1A67EL github-actions
    password: "ubuntu123"
    lock_passwd: false

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - helm
  - kubectl

runcmd:
  - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu && chmod 440 /etc/sudoers.d/ubuntu
  - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true K3S_KUBECONFIG_MODE="644" sh -
  - systemctl enable k3s
  - systemctl start k3s

final_message: "K3s ready"
