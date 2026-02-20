data "scaleway_instance_image" "ubuntu_jammy" {
  architecture = "x86_64"
  name         = "Ubuntu 22.04 Jammy Jellyfish"
  zone         = var.zone
}

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

  additional_volume_ids = [scaleway_instance_volume.data_volume.id]

  user_data = {
    "user-data" = templatefile("${path.module}/cloud-init.yaml.tpl", {
      k3s_token = random_password.k3s_token.result
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "scaleway_instance_volume" "data_volume" {
  zone       = var.zone
  type       = "b_ssd"
  size_in_gb = 125
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
    ${scaleway_instance_server.gpu_server.public_ips[0]} k3s_url=https://${scaleway_instance_server.gpu_server.public_ips[0]}:6443 k3s_token=${random_password.k3s_token.result}

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
    INSTANCE_IP=${scaleway_instance_server.gpu_server.public_ips[0]}
    INSTANCE_ID=${scaleway_instance_server.gpu_server.id}
    K3S_TOKEN=${random_password.k3s_token.result}
    REGION=${var.region}
    ZONE=${var.zone}
  EOF
  filename = "${path.module}/.env"
}
