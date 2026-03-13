# Output values for homelab environment

output "homelab_ip" {
  description = "IP address of homelab server"
  value       = var.homelab_ip
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = module.k3s_cluster.kubeconfig_path
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = module.argocd_bootstrap.argocd_url
}

output "argocd_password_file" {
  description = "Path to ArgoCD initial admin password file"
  value       = module.argocd_bootstrap.initial_password_file
}
