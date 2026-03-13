# K3s Cluster Installation Module
# Installs K3s on target instance via remote-exec

resource "null_resource" "k3s_install" {
  triggers = {
    instance_ip = var.instance_ip
    k3s_version = var.k3s_version
  }

  connection {
    type        = "ssh"
    host        = var.instance_ip
    user        = "ubuntu"
    private_key = var.ssh_private_key
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Installing K3s ${var.k3s_version} for environment: ${var.environment}'",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${var.k3s_version} sh -s - --write-kubeconfig-mode 644",
      "sudo systemctl enable k3s",
      "sudo systemctl start k3s",
      "timeout 300 bash -c 'until sudo k3s kubectl get nodes | grep -q Ready; do sleep 5; done'",
      "echo 'K3s installation complete'"
    ]
  }
}

resource "null_resource" "kubeconfig_fetch" {
  depends_on = [null_resource.k3s_install]

  triggers = {
    instance_ip = var.instance_ip
  }

  connection {
    type        = "ssh"
    host        = var.instance_ip
    user        = "ubuntu"
    private_key = var.ssh_private_key
    timeout     = "2m"
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -i ${path.module}/../../../ssh_key ubuntu@${var.instance_ip} \
        "sudo cat /etc/rancher/k3s/k3s.yaml" | \
        sed 's/127.0.0.1/${var.instance_ip}/g' > ${path.module}/kubeconfig-${var.environment}.yaml
    EOT
  }
}
