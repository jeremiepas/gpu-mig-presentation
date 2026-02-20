variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
  default     = "fr-par-1"
}

variable "project_id" {
  description = "Scaleway project ID"
  type        = string
  default     = "bbaff92f-ddd8-493b-8d03-05de850deb29"
}

variable "instance_type" {
  description = "GPU instance type"
  type        = string
  default     = "L4-1-24G"
}

variable "instance_name" {
  description = "Instance name"
  type        = string
  default     = "scw-cool-lamport-system"
}

variable "ssh_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "tags" {
  description = "Tags for resources"
  type        = list(string)
  default     = ["mig-demo", "presentation"]
}
