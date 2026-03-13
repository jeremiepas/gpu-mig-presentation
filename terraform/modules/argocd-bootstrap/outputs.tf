# Output values for argocd-bootstrap module

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://${var.instance_ip}:443"
}

output "initial_password_file" {
  description = "Path to file containing initial admin password"
  value       = "${path.module}/argocd-password-${var.environment}.txt"
}

output "argocd_ready" {
  description = "Trigger indicating ArgoCD is ready"
  value       = null_resource.argocd_install.id
}
