# Input variables for argocd-bootstrap module

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

variable "git_repo_url" {
  type        = string
  description = "Git repository URL for ArgoCD applications"
}

variable "k3s_ready" {
  type        = string
  description = "Dependency trigger from K3s cluster module"
}
