# Variable declarations for homelab environment

variable "homelab_ip" {
  type        = string
  description = "IP address of existing homelab GPU server"
}

variable "k3s_version" {
  type        = string
  description = "K3s version to install"
  default     = "v1.28.5+k3s1"
}

variable "git_repo_url" {
  type        = string
  description = "Git repository URL for ArgoCD applications"
  default     = "https://github.com/jeremie-lesage/gentle-circuit.git"
}
