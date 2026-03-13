# Input variables for k3s-cluster module

variable "instance_ip" {
  type        = string
  description = "IP address of the target instance"
}

variable "ssh_private_key" {
  type        = string
  description = "SSH private key for instance access"
  sensitive   = true
}

variable "environment" {
  type        = string
  description = "Environment name (prod, pre-prod, homelab)"
  validation {
    condition     = contains(["prod", "pre-prod", "homelab"], var.environment)
    error_message = "Environment must be one of: prod, pre-prod, homelab"
  }
}

variable "k3s_version" {
  type        = string
  description = "K3s version to install"
  default     = "v1.28.5+k3s1"
}
