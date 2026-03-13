# Terraform and provider version constraints for pre-prod environment

terraform {
  required_version = ">= 1.0"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.40"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
