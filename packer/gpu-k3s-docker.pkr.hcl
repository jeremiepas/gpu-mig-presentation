packer {
  required_plugins {
    scaleway = {
      version = ">= 1.0"
      source  = "github.com/scaleway/scaleway"
    }
  }
}

variable "project_id" {
  type        = string
  description = "Scaleway project ID"
  sensitive   = true
}

variable "zone" {
  type    = string
  default = "fr-par-2"
}

variable "image_name" {
  type    = string
  default = "gpu-k3s-docker-ubuntu-22.04"
}

variable "instance_type" {
  type    = string
  default = "H100-1-80G"
}

variable "region" {
  type    = string
  default = "fr-par"
}

source "scaleway" "gpu-image" {
  project_id      = var.project_id
  zone            = var.zone
  region          = var.region
  image_name      = var.image_name
  image_id        = "fr-par/ubuntu-jammy-22.04"  # Base Ubuntu 22.04 image
  server_type     = var.instance_type
  ssh_username    = "root"

  # Run provisioners
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/provision-gpu.sh"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/provision-docker.sh"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/provision-k3s.sh"
  }

  # Tag the image
  tags = {
    os        = "ubuntu"
    version   = "22.04"
    gpu       = "enabled"
    k3s       = "enabled"
    docker    = "enabled"
    managed   = "packer"
  }
}

build {
  name = "gpu-k3s-docker"
  sources = ["source.scaleway.gpu-image"]

  # Post-provisioning: cleanup
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/cleanup.sh"
  }
}
