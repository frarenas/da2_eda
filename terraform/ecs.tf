# Este archivo define el cluster base de ECS.

# --- 1. ECS Cluster ---
resource "aws_ecs_cluster" "rabbitmq_cluster" {
  name = "citypass-rabbitmq-cluster"

  tags = {
    Name = "RabbitMQ-ECS-Cluster"
  }
}
