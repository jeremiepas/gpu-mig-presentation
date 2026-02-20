output "instance_ip" {
  description = "Public IP of the GPU instance"
  value       = scaleway_instance_server.gpu_server.public_ips[0]
}

output "instance_id" {
  description = "Instance ID"
  value       = scaleway_instance_server.gpu_server.id
}

output "k3s_install_command" {
  description = "Command to install K3s"
  value       = "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=\"644\" sh -"
}
