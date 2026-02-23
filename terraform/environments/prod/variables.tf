variable "region" {
  description = "Scaleway region"
  type        = string
  default     = "fr-par"
}

variable "zone" {
  description = "Scaleway zone"
  type        = string
  default     = "fr-par-2"
}

variable "project_id" {
  description = "Scaleway project ID"
  type        = string
  default     = "bbaff92f-ddd8-493b-8d03-05de850deb29"
}

variable "instance_type" {
  description = "Instance type for prod environment"
  type        = string
  default     = "GPU-START1-S"
}

variable "instance_name" {
  description = "Instance name"
  type        = string
  default     = "prod-gpu-mig-demo"
}

variable "tags" {
  description = "Tags for resources"
  type        = list(string)
  default     = ["prod", "gpu-mig", "presentation"]
}