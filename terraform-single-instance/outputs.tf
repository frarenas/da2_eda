output "rabbitmq_service_arn" {
  description = "ARN del servicio ECS (use esto para investigar tareas)."
  value       = aws_ecs_service.rabbitmq.arn
}

output "rabbitmq_task_definition" {
  description = "Task definition ARN usada por el servicio."
  value       = aws_ecs_task_definition.rabbitmq.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group donde los logs del contenedor aparecen."
  value       = aws_cloudwatch_log_group.rabbitmq_logs.name
}

output "how_to_get_task_public_ip_example" {
  description = "Ejemplo de comando AWS CLI para obtener la IP pública de la tarea (ejecutar localmente una vez desplegado)."
  value       = <<EOF
# List tasks for the service and get the task ARN
TASK_ARN=$(aws ecs list-tasks --cluster ${aws_ecs_cluster.citypass.id} --service-name ${aws_ecs_service.rabbitmq.name} --query 'taskArns[0]' --output text)
# Describe the task to get the ENI
ENI_ID=$(aws ecs describe-tasks --cluster ${aws_ecs_cluster.citypass.id} --tasks $TASK_ARN --query 'tasks[0].attachments[0].details[?name==\"networkInterfaceId\"].value' --output text)
# Describe the ENI to get the public IP
aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text
EOF
}
