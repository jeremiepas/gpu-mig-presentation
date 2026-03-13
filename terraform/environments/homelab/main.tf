# Homelab Environment Configuration
# Configures K3s and ArgoCD on existing server (no infrastructure provisioning)

terraform {
  required_version = ">= 1.0"

  # Local backend - no S3
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# No Scaleway provider - server already exists

# K3s Cluster Installation on existing server
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  instance_ip     = var.homelab_ip
  ssh_private_key = file("${path.module}/../../../ssh_key")
  environment     = "homelab"
  k3s_version     = var.k3s_version
}

# ArgoCD Bootstrap on existing K3s
module "argocd_bootstrap" {
  source = "../../modules/argocd-bootstrap"

  instance_ip     = var.homelab_ip
  ssh_private_key = file("${path.module}/../../../ssh_key")
  environment     = "homelab"
  git_repo_url    = var.git_repo_url
  k3s_ready       = module.k3s_cluster.cluster_ready
}
