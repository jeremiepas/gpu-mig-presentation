resource "scaleway_iam_ssh_key" "dev_key" {
  name       = "dev-key"
  public_key = file("${path.module}/../../../ssh_key.pub")
  project_id = var.project_id
}

resource "scaleway_instance_server" "dev_server" {
  name  = var.instance_name
  type  = var.instance_type
  zone  = var.zone
  image = "ubuntu_jammy"
  ip_id = scaleway_instance_ip.dev_ip.id
  tags  = var.tags

  root_volume {
    size_in_gb = 20
  }

  user_data = {
    "user-data" = templatefile("${path.module}/../../cloud-init.yaml.tpl", {
      ssh_public_key = file("${path.module}/../../../ssh_key.pub")
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "scaleway_instance_ip" "dev_ip" {
  zone = var.zone
  tags = var.tags
}

resource "local_file" "dev_inventory" {
  content  = <<-EOF
    [server]
    ${scaleway_instance_server.dev_server.public_ips[0].address}

    [all:vars]
    ansible_user=root
  EOF
  filename = "${path.module}/inventory"
}

resource "local_file" "dev_env" {
  content  = <<-EOF
    INSTANCE_IP=${scaleway_instance_server.dev_server.public_ips[0].address}
    INSTANCE_ID=${scaleway_instance_server.dev_server.id}
    REGION=${var.region}
    ZONE=${var.zone}
  EOF
  filename = "${path.module}/.env"
}
