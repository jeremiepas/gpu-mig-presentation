# Output values for scaleway-instance module

output "instance_ip" {
  description = "Public IP address of the instance"
  value       = scaleway_instance_ip.main.address
}

output "instance_id" {
  description = "ID of the instance"
  value       = scaleway_instance_server.main.id
}

output "instance_name" {
  description = "Name of the instance"
  value       = scaleway_instance_server.main.name
}
