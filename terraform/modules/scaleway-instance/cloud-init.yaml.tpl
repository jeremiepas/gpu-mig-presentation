#cloud-config
# Cloud-init configuration for Scaleway GPU instance
# Environment: ${environment}

users:
  - name: ubuntu
    ssh_authorized_keys:
      - ${ssh_public_key}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - vim
  - htop

runcmd:
  - echo "Instance provisioned for environment: ${environment}" > /etc/environment-info
  - systemctl enable ssh
  - systemctl start ssh
