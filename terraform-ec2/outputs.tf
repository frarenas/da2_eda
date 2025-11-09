output "public_ip" {
  description = "Public IP of the EC2 host running docker-compose"
  value       = aws_instance.host.public_ip
}

output "public_dns" {
  description = "Public DNS of the EC2 host"
  value       = aws_instance.host.public_dns
}

output "ssh_command" {
  description = "Example SSH command to connect to the host (if you provided a key_name)"
  value       = var.key_name != "" ? "ssh -i <path-to-key.pem> ubuntu@${aws_instance.host.public_ip}" : "ssh ubuntu@${aws_instance.host.public_ip}"
}
