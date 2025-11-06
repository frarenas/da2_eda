# No usamos data "aws_secretsmanager_secret" debido a las restricciones de permisos.

# --- 1. ECS Task Definition (Fargate) ---
resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "rabbitmq-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024" # 1 vCPU
  memory                   = "2048" # 2 GB

  # Use an existing role ARN via variable, or create one by enabling var.create_task_execution_role
  execution_role_arn = var.create_task_execution_role ? aws_iam_role.ecs_task_execution[0].arn : (var.execution_role_arn != "" ? var.execution_role_arn : "")

  # Definición del contenedor
  container_definitions = jsonencode([
    {
      name      = "rabbitmq"
      image     = "rabbitmq:3-management" # Use a known RabbitMQ image with management plugin
      essential = true
      portMappings = [
        { containerPort = 5672, hostPort = 5672, protocol = "tcp" },   # AMQP
        { containerPort = 15672, hostPort = 15672, protocol = "tcp" }, # Management UI
        { containerPort = 25672, hostPort = 25672, protocol = "tcp" }  # Erlang Clustering
      ]

      # Use the image default entrypoint/command. Setting the nodename to the
      # container IP (as we did previously) caused Erlang distribution errors
      # during the prelaunch phase (nodistribution). The default startup works
      # for a single-node setup; for clustering we'll change this later.

      # Send container logs to CloudWatch for easier debugging. Ensure the execution role has permissions.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/rabbitmq"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "rabbitmq"
        }
      }

      # VARIABLES DE ENTORNO PARA CLUSTERING
      environment = [
        # Erlang cookie for cluster/authentication. For single-node debugging a
        # hard-coded value is acceptable; when scaling, use Secrets Manager.
        { name = "RABBITMQ_ERLANG_COOKIE", value = "RRKYXMQLSXURFZSUXFFU" },
        # Create a management user so the web UI is accessible for debugging
        { name = "RABBITMQ_DEFAULT_USER", value = var.rabbitmq_admin_user },
        { name = "RABBITMQ_DEFAULT_PASS", value = var.rabbitmq_admin_pass }
      ]
    }
  ])
}

# --- 2. ECS Service (Despliegue de 3 réplicas) ---
resource "aws_ecs_service" "rabbitmq" {
  name                = "rabbitmq-service"
  cluster             = aws_ecs_cluster.rabbitmq_cluster.id # Usar el nombre de recurso de ecs.tf
  task_definition     = aws_ecs_task_definition.rabbitmq.arn
  desired_count       = 1 # Start with 1 replica to validate the task; scale to 3 after verification
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"

  # Configuración de red para Fargate
  network_configuration {
    security_groups = [aws_security_group.rabbitmq.id] # Usar el SG de RabbitMQ de security_groups.tf
    # Para que las tareas sean accesibles públicamente, las ubicamos en subredes públicas
    subnets = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    # Asignar IP pública a las tareas Fargate para acceso directo desde Internet
    assign_public_ip = true
  }
  # Register the management port (15672) with the ALB target group
  load_balancer {
    target_group_arn = aws_lb_target_group.rabbit_tg.arn
    container_name   = "rabbitmq"
    container_port   = 15672
  }
}
