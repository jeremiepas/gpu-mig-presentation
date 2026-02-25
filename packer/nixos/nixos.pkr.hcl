packer {
  required_plugins {
    scaleway = {
      version = ">= 1.0"
      source  = "github.com/scaleway/scaleway"
    }
  }
}

# ============================================================
# GPU K3s Docker Image Builder for Scaleway
# Uses Ubuntu 22.04 with NixOS configuration management
# ============================================================

variable "project_id" {
  type        = string
  description = "Scaleway project ID"
  sensitive   = true
}

variable "zone" {
  type    = string
  default = "fr-par-2"
}

variable "region" {
  type    = string
  default = "fr-par"
}

variable "image_name" {
  type    = string
  default = "gpu-k3s-docker-nixos-23.11"
}

variable "server_type" {
  type    = string
  default = "H100-1-80G"
}

variable "ssh_username" {
  type    = string
  default = "root"
}

variable "ssh_private_key_file" {
  type    = string
  default = ""  # Use SSH agent if not specified
}

variable "disk_size" {
  type    = number
  default = 100  # GB
}

# Build source: Ubuntu 22.04 base
source "scaleway" "gpu-image" {
  project_id      = var.project_id
  zone            = var.zone
  region          = var.region
  image_name      = var.image_name
  image_id        = "fr-par/ubuntu-jammy-22.04"
  server_type     = var.server_type
  ssh_username    = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_agent_auth  = true

  # Timing
  ssh_timeout     = "30m"
  shutdown_timeout = "10m"

  # Tags
  tags = {
    os        = "ubuntu"
    version   = "22.04"
    nixos     = "23.11"
    gpu       = "enabled"
    k3s       = "enabled"
    docker    = "enabled"
    managed   = "packer"
    purpose   = "gpu-mig-demo"
  }
}

build {
  name = "gpu-k3s-docker-nixos"
  sources = ["source.scaleway.gpu-image"]

  # ============================================================
  # Step 1: Install base packages and NixOS
  # ============================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/01-base-packages.sh"
  }

  # ============================================================
  # Step 2: Install NixOS package manager
  # ============================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/02-install-nix.sh"
  }

  # ============================================================
  # Step 3: Install NVIDIA GPU drivers
  # ============================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/03-nvidia-drivers.sh"
  }

  # ============================================================
  # Step 4: Install Docker with NVIDIA runtime
  # ============================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/04-docker.sh"
  }

  # ============================================================
  # Step 5: Install K3s
  # ============================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/05-k3s.sh"
  }

  # ============================================================
  # Step 6: Pre-pull Docker images for GPU workloads
  # ============================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/06-prepull-images.sh"
  }

  # ============================================================
  # Step 7: Copy NixOS configuration
  # ============================================================
  provisioner "file" {
    source      = "../../nixos/gpu-k3s-docker/"
    destination = "/tmp/nixos-config/"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    inline = [
      "mkdir -p /etc/nixos",
      "cp -r /tmp/nixos-config/* /etc/nixos/",
      "chmod +x /etc/nixos/configuration.nix"
    ]
  }

  # ============================================================
  # Step 8: Open all ports (security not a concern)
  # ============================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/07-open-ports.sh"
  }

  # ============================================================
  # Step 9: Cleanup and finalize
  # ============================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }} && {{ .Vars }} {{ .Path }}"
    script          = "scripts/99-cleanup.sh"
  }
}
