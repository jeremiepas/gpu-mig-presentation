# Local GPU Deployment with Null Resources
# Uses null_resource to manage remote execution on local GPU machine

resource "null_resource" "prepare_gpu_machine" {
  triggers = {
    host = var.gpu_host
    user = var.gpu_user
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Preparing GPU machine at ${var.gpu_host}'",
      "whoami",
      "uname -a",
      "# Install prerequisites if needed",
      "sudo apt-get update || true",
    ]

    connection {
      type        = "ssh"
      user        = var.gpu_user
      host        = var.gpu_host
      private_key = file(var.ssh_key_path)
      timeout     = "5m"
    }
  }
}

resource "null_resource" "install_k3s" {
  depends_on = [null_resource.prepare_gpu_machine]

  triggers = {
    host = var.gpu_host
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Installing K3s on local GPU machine'",

      # Check if K3s is already installed
      "if ! command -v k3s &> /dev/null; then",
      "  echo 'Installing K3s...'",
      "  curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE='644' sh -",
      "  sudo systemctl enable k3s",
      "  sudo systemctl start k3s",
      "  echo 'Waiting for K3s to be ready...'",
      "  sleep 30",
      "else",
      "  echo 'K3s already installed'",
      "fi",

      # Verify installation
      "sudo k3s kubectl get nodes || echo 'K3s is ready'"
    ]

    connection {
      type        = "ssh"
      user        = var.gpu_user
      host        = var.gpu_host
      private_key = file(var.ssh_key_path)
      timeout     = "10m"
    }
  }
}

resource "null_resource" "retrieve_kubeconfig" {
  depends_on = [null_resource.install_k3s]

  provisioner "remote-exec" {
    inline = [
      "echo 'Retrieving kubeconfig'",
      "sudo cat /etc/rancher/k3s/k3s.yaml"
    ]

    connection {
      type        = "ssh"
      user        = var.gpu_user
      host        = var.gpu_host
      private_key = file(var.ssh_key_path)
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      ssh -i ${var.ssh_key_path} -o StrictHostKeyChecking=no ${var.gpu_user}@${var.gpu_host} "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config-gpu-local 2>/dev/null || echo "Could not retrieve kubeconfig"
      if [ -f ~/.kube/config-gpu-local ]; then
        sed -i "s|127.0.0.1|${var.gpu_host}|g" ~/.kube/config-gpu-local
        chmod 600 ~/.kube/config-gpu-local
        echo "kubeconfig saved to ~/.kube/config-gpu-local"
      fi
    EOT
  }
}

resource "null_resource" "copy_manifests" {
  depends_on = [null_resource.install_k3s]

  provisioner "local-exec" {
    command = <<EOT
      echo "Copying Kubernetes manifests to remote server..."
      scp -i ${var.ssh_key_path} -o StrictHostKeyChecking=no \
        ../../../../k8s/00-namespaces.yaml \
        ../../../../k8s/01-gpu-operator.yaml \
        ../../../../k8s/02-timeslicing-config.yaml \
        ../../../../k8s/03-prometheus.yaml \
        ../../../../k8s/04-grafana.yaml \
        ../../../../k8s/04-grafana-datasources.yaml \
        ${var.gpu_user}@${var.gpu_host}:~/
    EOT
  }
}

resource "null_resource" "apply_manifests" {
  depends_on = [null_resource.copy_manifests]

  provisioner "remote-exec" {
    inline = [
      "echo 'Applying Kubernetes manifests'",

      # Create directory for manifests
      "mkdir -p ~/k8s-manifests",

      # Move copied manifests to directory
      "mv ~/0*.yaml ~/k8s-manifests/ 2>/dev/null || true",

      # Apply namespaces
      "sudo k3s kubectl apply -f ~/k8s-manifests/00-namespaces.yaml",

      # Apply GPU operator
      "sudo k3s kubectl apply -f ~/k8s-manifests/01-gpu-operator.yaml",

      # Apply time slicing config (default)
      "sudo k3s kubectl apply -f ~/k8s-manifests/02-timeslicing-config.yaml",

      # Apply monitoring stack
      "sudo k3s kubectl apply -f ~/k8s-manifests/03-prometheus.yaml",
      "sudo k3s kubectl apply -f ~/k8s-manifests/04-grafana.yaml",
      "sudo k3s kubectl apply -f ~/k8s-manifests/04-grafana-datasources.yaml",

      # Wait a bit for deployments to initialize
      "sleep 30",

      "echo 'Kubernetes manifests applied successfully'"
    ]

    connection {
      type        = "ssh"
      user        = var.gpu_user
      host        = var.gpu_host
      private_key = file(var.ssh_key_path)
      timeout     = "10m"
    }
  }
}

resource "local_file" "local_env" {
  content = templatefile("${path.module}/../templates/local-env.tmpl", {
    gpu_host       = var.gpu_host
    gpu_user       = var.gpu_user
    ssh_key_path   = var.ssh_key_path
    k3s_api_url    = "https://${var.gpu_host}:${var.k3s_port}"
    grafana_url    = "http://${var.gpu_host}:30300"
    prometheus_url = "http://${var.gpu_host}:30090"
  })

  filename = "${path.module}/.env"
}

# Template file for local environment variables
resource "local_file" "kubeconfig_script" {
  content = templatefile("${path.module}/../templates/get-kubeconfig.sh.tmpl", {
    gpu_host     = var.gpu_host
    gpu_user     = var.gpu_user
    ssh_key_path = var.ssh_key_path
  })

  filename = "${path.module}/get-kubeconfig.sh"
}