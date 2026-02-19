#cloud-config
package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - helm
  - kubectl
  - python3
  - python3-pip
  - containerd

runcmd:
  - systemctl enable containerd
  - systemctl start containerd
  - curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true K3S_KUBECONFIG_MODE="644" sh -
  - systemctl enable k3s
  - systemctl start k3s
  - sleep 30
  - kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get nodes
  - kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml taint nodes --all node-role.kubernetes.io/control-plane-
  - kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml label nodes --all node-role.kubernetes.io/worker=

final_message: "K3s GPU Node ready"
