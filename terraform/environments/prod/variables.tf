# Variable declarations for prod environment

variable "region" {
  type        = string
  description = "Scaleway region"
  default     = "fr-par"
}

variable "zone" {
  type        = string
  description = "Scaleway zone"
  default     = "fr-par-1"
}

variable "project_id" {
  type        = string
  description = "Scaleway project ID"
}

variable "instance_type" {
  type        = string
  description = "Scaleway instance type"
  default     = "H100-1-80G"
}

variable "instance_name" {
  type        = string
  description = "Instance name"
  default     = "gpu-mig-prod"
}

variable "tags" {
  type        = list(string)
  description = "Tags to apply to resources"
  default     = ["prod", "gpu", "mig-demo"]
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
