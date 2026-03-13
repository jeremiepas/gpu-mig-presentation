# Production Environment Configuration
# Provisions Scaleway GPU instance, K3s cluster, and ArgoCD

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }
    region                      = "fr-par"
    bucket                      = "gpu-mig-presentation-tfstate"
    key                         = "prod/terraform.tfstate"
    skip_credentials_validation = true
    skip_region_validation      = true
  }

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

provider "scaleway" {
  region     = var.region
  zone       = var.zone
  project_id = var.project_id
}

# Scaleway GPU Instance
module "scaleway_instance" {
  source = "../../modules/scaleway-instance"

  environment      = "prod"
  instance_type    = var.instance_type
  instance_name    = var.instance_name
  zone             = var.zone
  tags             = var.tags
  ssh_public_key   = file("${path.module}/../../../ssh_key.pub")
  root_volume_size = var.root_volume_size
  image_id         = var.image_id
}

# K3s Cluster Installation
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  instance_ip     = module.scaleway_instance.instance_ip
  ssh_private_key = file("${path.module}/../../../ssh_key")
  environment     = "prod"
  k3s_version     = var.k3s_version
}

# ArgoCD Bootstrap
module "argocd_bootstrap" {
  source = "../../modules/argocd-bootstrap"

  instance_ip     = module.scaleway_instance.instance_ip
  ssh_private_key = file("${path.module}/../../../ssh_key")
  environment     = "prod"
  git_repo_url    = var.git_repo_url
  k3s_ready       = module.k3s_cluster.cluster_ready
}
