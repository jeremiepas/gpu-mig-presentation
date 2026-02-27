terraform {
  required_version = ">= 1.0"

  # Using local backend for local deployment
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

# Variables for local GPU deployment
variable "gpu_host" {
  description = "IP address of the local GPU machine"
  type        = string
  default     = "192.168.1.96"
}

variable "gpu_user" {
  description = "Username for the GPU machine"
  type        = string
  default     = "jeremie"
}

variable "ssh_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "../../../ssh_key"
}

# Null provider to manage remote connections
provider "null" {}

# Local provider for file management
provider "local" {}