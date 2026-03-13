# Output values for k3s-cluster module

output "cluster_ready" {
  description = "Trigger indicating K3s cluster is ready"
  value       = null_resource.k3s_install.id
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = "${path.module}/kubeconfig-${var.environment}.yaml"
}

output "k3s_version" {
  description = "Installed K3s version"
  value       = var.k3s_version
}
