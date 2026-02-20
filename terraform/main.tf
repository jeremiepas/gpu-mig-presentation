terraform {
  required_version = ">= 1.0"
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.40"
    }
  }
  backend "s3" {
    endpoints = {
      s3 = "s3.fr-par.scw.cloud"
    }
    bucket                      = "gpu-mig-presentation-tfstate"
    key                         = "terraform.tfstate"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    force_path_style            = true
  }
}

provider "scaleway" {
  region     = var.region
  zone       = var.zone
  project_id = var.project_id
}
