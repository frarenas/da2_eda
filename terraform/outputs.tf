output "vpc_id" {
  description = "El ID de la VPC creada."
  value       = aws_vpc.citypass_vpc.id
}

output "private_subnets" {
  description = "IDs de las subredes privadas (para Fargate)."
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "public_subnets" {
  description = "IDs de las subredes públicas (para Load Balancer)."
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "rabbitmq_sg_id" {
  description = "ID del Security Group de RabbitMQ (para la Task Definition)."
  value       = aws_security_group.rabbitmq.id
}
