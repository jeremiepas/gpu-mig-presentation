packer {
  required_plugins {
    scaleway = {
      version = ">= 1.1.0"
      source  = "github.com/scaleway/scaleway"
    }
  }
}

# =============================================================================
# GPU Moshi Demo Image Builder for Scaleway
# =============================================================================
# Purpose: Optimized GPU image for Moshi demo with MIG and Time Slicing
# Base: Ubuntu 22.04 LTS
# Components: NVIDIA drivers, Docker + NVIDIA runtime, K3s, Moshi deps
# Features: MIG and Time Slicing configuration support
# =============================================================================

variable "project_id" {
  type        = string
  description = "Scaleway project ID"
  sensitive   = true
}

variable "zone" {
  type        = string
  default     = "fr-par-2"
  description = "Scaleway zone"
}

variable "image_name" {
  type        = string
  default     = "gpu-moshi-demo-ubuntu-22.04"
  description = "Name for the built image"
}

variable "instance_type" {
  type        = string
  default     = "H100-1-80G"
  description = "Scaleway instance type (L4-24GB GPU)"
}

variable "ssh_username" {
  type        = string
  default     = "root"
  description = "SSH username for provisioning"
}

variable "disk_size" {
  type        = number
  default     = 80
  description = "Disk size in GB"
}

variable "gpu_mode" {
  type        = string
  default     = "both"
  description = "GPU mode: mig, timeslicing, or both"
}

# Build source: Ubuntu 22.04 LTS with GPU support
source "scaleway" "gpu-moshi" {
  project_id          = var.project_id
  zone                 = var.zone
  image               = "ubuntu_jammy_gpu_os_12"
  commercial_type     = var.instance_type
  ssh_username        = var.ssh_username
  ssh_agent_auth      = true
}

build {
  name    = "gpu-moshi-demo"
  sources = ["source.scaleway.gpu-moshi"]

  # =============================================================================
  # Step 1: Base System Setup & Security Hardening
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/01-base-setup.sh"
  }

  # =============================================================================
  # Step 2: NVIDIA GPU Drivers & CUDA
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/02-nvidia-drivers.sh"
  }

  # =============================================================================
  # Step 3: Docker with NVIDIA Container Runtime
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/03-docker.sh"
  }

  # =============================================================================
  # Step 4: K3s Kubernetes
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/04-k3s.sh"
  }

  # =============================================================================
  # Step 5: Moshi Demo Dependencies
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/05-moshi-deps.sh"
  }

  # =============================================================================
  # Step 6: GPU Configuration (MIG & Time Slicing)
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/06-gpu-configs.sh"
  }

  # =============================================================================
  # Step 7: Moshi Models Pre-download (Preload ALL models for instant start)
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/07-models-setup.sh"
  }

  # =============================================================================
  # Step 8: Security Hardening
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/08-security.sh"
  }

  # =============================================================================
  # Step 9: Cleanup & Finalize
  # =============================================================================
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} {{ .Path }}"
    script          = "scripts/99-cleanup.sh"
  }
}
