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
      s3 = "https://s3.fr-par.scw.cloud"
    }
    bucket                      = "gpu-mig-presentation-tfstate"
    key                         = "terraform.tfstate"
    region                      = "fr-par"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}

provider "scaleway" {
  region     = var.region
  zone       = var.zone
  project_id = var.project_id
}
