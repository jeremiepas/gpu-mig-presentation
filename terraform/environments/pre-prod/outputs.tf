# Output values for pre-prod environment

output "instance_ip" {
  description = "Public IP address of the pre-prod instance"
  value       = module.scaleway_instance.instance_ip
}

output "instance_id" {
  description = "ID of the pre-prod instance"
  value       = module.scaleway_instance.instance_id
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
