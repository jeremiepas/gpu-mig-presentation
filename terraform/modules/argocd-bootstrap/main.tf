# ArgoCD Bootstrap Module
# Installs ArgoCD on K3s cluster via remote-exec

resource "null_resource" "argocd_install" {
  depends_on = [var.k3s_ready]

  triggers = {
    instance_ip  = var.instance_ip
    environment  = var.environment
    git_repo_url = var.git_repo_url
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
      "echo 'Installing ArgoCD for environment: ${var.environment}'",

      # Create ArgoCD namespace
      "sudo k3s kubectl create namespace argocd --dry-run=client -o yaml | sudo k3s kubectl apply -f -",

      # Install ArgoCD
      "sudo k3s kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml",

      # Wait for ArgoCD to be ready
      "timeout 300 bash -c 'until sudo k3s kubectl get pods -n argocd | grep -q Running; do sleep 5; done'",
      "sudo k3s kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s",

      "echo 'ArgoCD installation complete'"
    ]
  }
}

resource "null_resource" "argocd_password" {
  depends_on = [null_resource.argocd_install]

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
        "sudo k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" \
        > ${path.module}/argocd-password-${var.environment}.txt
    EOT
  }
}
