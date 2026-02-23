output "instance_ip" {
  description = "Public IP of the dev instance"
  value       = scaleway_instance_server.dev_server.public_ips[0].address
}

output "instance_id" {
  description = "Instance ID"
  value       = scaleway_instance_server.dev_server.id
}

output "instance_dns" {
  description = "Public DNS of the instance (use without zone prefix)"
  value       = "${split("/", scaleway_instance_server.dev_server.id)[1]}.pub.instances.scw.cloud"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh root@${scaleway_instance_server.dev_server.public_ips[0].address}"
}

output "grafana_url" {
  description = "Grafana URL (path-based routing)"
  value       = "http://${split("/", scaleway_instance_server.dev_server.id)[1]}.pub.instances.scw.cloud/grafana"
}

output "prometheus_url" {
  description = "Prometheus URL (path-based routing)"
  value       = "http://${split("/", scaleway_instance_server.dev_server.id)[1]}.pub.instances.scw.cloud/prometheus"
}