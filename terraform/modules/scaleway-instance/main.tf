# Scaleway GPU Instance Module
# Provisions a Scaleway instance with GPU capabilities

resource "scaleway_instance_ip" "main" {
  zone = var.zone
  tags = concat(var.tags, [var.environment])
}

resource "scaleway_instance_server" "main" {
  name  = var.instance_name
  type  = var.instance_type
  zone  = var.zone
  image = var.image_id
  tags  = concat(var.tags, [var.environment])

  root_volume {
    size_in_gb = var.root_volume_size
  }

  ip_id = scaleway_instance_ip.main.id

  user_data = {
    cloud-init = templatefile("${path.module}/cloud-init.yaml.tpl", {
      ssh_public_key = var.ssh_public_key
      environment    = var.environment
    })
  }
}
