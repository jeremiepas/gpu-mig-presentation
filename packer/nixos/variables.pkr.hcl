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
  default = "nixos-gpu-k3s-docker"
}

variable "server_type" {
  type    = string
  default = "H100-1-80G"
}

variable "ssh_username" {
  type    = string
  default = "root"
}

variable "disk_size" {
  type    = number
  default = 50  # GB
}
