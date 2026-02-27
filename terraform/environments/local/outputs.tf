output "gpu_host" {
  description = "IP address of the local GPU machine"
  value       = var.gpu_host
}

output "gpu_user" {
  description = "Username for the GPU machine"
  value       = var.gpu_user
}

output "k3s_api_url" {
  description = "K3s API URL for local access"
  value       = "https://${var.gpu_host}:${var.k3s_port}"
}

output "grafana_url" {
  description = "Grafana URL for local access"
  value       = "http://${var.gpu_host}:30300"
}

output "prometheus_url" {
  description = "Prometheus URL for local access"
  value       = "http://${var.gpu_host}:30090"
}

output "ssh_command" {
  description = "SSH command to connect to GPU machine"
  value       = "ssh -i ${var.ssh_key_path} ${var.gpu_user}@${var.gpu_host}"
}

output "kubeconfig_path" {
  description = "Local path where kubeconfig is stored"
  value       = var.kubeconfig_local_path
}