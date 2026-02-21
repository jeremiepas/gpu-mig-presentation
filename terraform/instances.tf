resource "scaleway_instance_server" "gpu_server" {
  name  = var.instance_name
  type  = var.instance_type
  zone  = var.zone
  image = "741cfd27-a822-4c82-b80f-973b562743ad"
  ip_id = scaleway_instance_ip.gpu_ip.id
  tags  = var.tags

  root_volume {
    delete_on_termination = true
  }

  user_data = {
    "user-data" = templatefile("${path.module}/cloud-init.yaml.tpl", {
      k3s_token = random_password.k3s_token.result
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "scaleway_instance_ip" "gpu_ip" {
  zone = var.zone
  tags = var.tags
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "local_file" "k3s_inventory" {
  content  = <<-EOF
    [server]
    ${scaleway_instance_server.gpu_server.public_ips[0].address} k3s_url=https://${scaleway_instance_server.gpu_server.public_ips[0].address}:6443 k3s_token=${random_password.k3s_token.result}

    [agent]
    
    [k3s:children]
    server
    agent
  EOF
  filename = "${path.module}/../k8s/inventory"
}

resource "local_file" "terraform_outputs" {
  content  = <<-EOF
    # Terraform outputs for GitHub Actions
    INSTANCE_IP=${scaleway_instance_server.gpu_server.public_ips[0].address}
    INSTANCE_ID=${scaleway_instance_server.gpu_server.id}
    K3S_TOKEN=${random_password.k3s_token.result}
    REGION=${var.region}
    ZONE=${var.zone}
  EOF
  filename = "${path.module}/.env"
}
