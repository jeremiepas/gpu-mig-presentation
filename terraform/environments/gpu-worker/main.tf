terraform {
  required_version = ">= 1.0"

  backend "s3" {
    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }
    region                      = "fr-par"
    bucket                      = "gpu-mig-presentation-tfstate"
    key                         = "gpu-worker/terraform.tfstate"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.40"
    }
  }
}

provider "scaleway" {
  region     = "fr-par"
  zone       = "fr-par-2"
  project_id = "bbaff92f-ddd8-493b-8d03-05de850deb29"
}

variable "instance_type" {
  description = "GPU instance type"
  type        = string
  default     = "H100-1-80G"
}

variable "timeout_minutes" {
  description = "Auto-shutdown timeout in minutes"
  type        = number
  default     = 25
}

resource "scaleway_iam_ssh_key" "gpu_worker_key" {
  name       = "gpu-worker-key"
  public_key = file("${path.module}/../../../ssh_key.pub")
  project_id = "bbaff92f-ddd8-493b-8d03-05de850deb29"
}

resource "scaleway_instance_server" "gpu_worker" {
  name  = "gpu-worker"
  type  = var.instance_type
  zone  = "fr-par-2"
  image = "ubuntu_jammy"
  tags  = ["gpu-worker", "on-demand", "auto-shutdown"]

  root_volume {
    size_in_gb = 50
  }

  user_data = {
    "user-data" = templatefile("${path.module}/cloud-init-gpu.yaml.tpl", {
      ssh_public_key = file("${path.module}/../../../ssh_key.pub")
      master_ip      = "51.159.167.215"
      shutdown_mins  = var.timeout_minutes
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "scaleway_instance_ip" "gpu_worker_ip" {
  zone = "fr-par-2"
  tags = ["gpu-worker", "on-demand"]
}

resource "local_file" "gpu_worker_env" {
  content  = <<-EOF
INSTANCE_IP=${scaleway_instance_server.gpu_worker.public_ips[0].address}
INSTANCE_ID=${scaleway_instance_server.gpu_worker.id}
REGION=fr-par
ZONE=fr-par-2
TIMEOUT_MINUTES=${var.timeout_minutes}
EOF
  filename = "${path.module}/.env"
}

output "instance_ip" {
  value = scaleway_instance_server.gpu_worker.public_ips[0].address
}

output "instance_id" {
  value = scaleway_instance_server.gpu_worker.id
}

output "ssh_command" {
  value = "ssh -i ssh_key ubuntu@${scaleway_instance_server.gpu_worker.public_ips[0].address}"
}
