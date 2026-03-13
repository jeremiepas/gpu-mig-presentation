# Input variables for scaleway-instance module

variable "environment" {
  type        = string
  description = "Environment name (prod, pre-prod, homelab)"
  validation {
    condition     = contains(["prod", "pre-prod", "homelab"], var.environment)
    error_message = "Environment must be one of: prod, pre-prod, homelab"
  }
}

variable "instance_type" {
  type        = string
  description = "Scaleway instance type (e.g., H100-1-80G, GPU-3070-S)"
}

variable "instance_name" {
  type        = string
  description = "Name for the instance"
}

variable "zone" {
  type        = string
  description = "Scaleway zone (e.g., fr-par-1)"
  default     = "fr-par-1"
}

variable "tags" {
  type        = list(string)
  description = "Tags to apply to the instance"
  default     = []
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for instance access"
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 50
}

variable "image_id" {
  type        = string
  description = "Scaleway image ID"
  default     = "ubuntu_jammy"
}
