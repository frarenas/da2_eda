# No usamos data "aws_secretsmanager_secret" debido a las restricciones de permisos.

# --- 1. ECS Task Definition (Fargate) ---
resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "rabbitmq-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024" # 1 vCPU
  memory                   = "2048" # 2 GB

  execution_role_arn = "arn:aws:iam::767397732475:role/LabRole"

  # Definición del contenedor
  container_definitions = jsonencode([
    {
      name      = "rabbitmq"
      image     = "rabbitmq:4-management" # Usar la imagen base con plugin de management
      essential = true
      portMappings = [
        { containerPort = 5672, hostPort = 5672, protocol = "tcp" },   # AMQP
        { containerPort = 15672, hostPort = 15672, protocol = "tcp" }, # Management UI
        { containerPort = 25672, hostPort = 25672, protocol = "tcp" }  # Erlang Clustering
      ]

      command = [
        "sh",
        "-c",
        "export RABBITMQ_NODENAME=rabbit@$(hostname -i) && /usr/local/bin/docker-entrypoint.sh rabbitmq-server"
      ]

      # VARIABLES DE ENTORNO PARA CLUSTERING
      environment = [
        # Se pasa la cookie directamente para evitar Secrets Manager/IAM
        { name = "RABBITMQ_ERLANG_COOKIE", value = "RRKYXMQLSXURFZSUXFFU" },
        # Forzamos a RabbitMQ a usar las IPs en lugar del hostname (necesario sin Service Discovery)
        #{ name = "RABBITMQ_USE_LONGNAME", value = "false" },
        # El nombre del nodo debe coincidir con el hostname, que en Fargate es la IP privada.
        # RabbitMQ lo detectará automáticamente.
        #{ name = "RABBITMQ_NODENAME", value = "rabbit@$(hostname -s)" },
        # Deshabilitamos la detección de pares para forzar el clustering manual
        #{ name = "RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS", value = "-rabbit cluster_formation classic_config -rabbit cluster_formation.classic_config.nodes '[\"rabbit@10.0.2.33\", \"rabbit@10.0.4.171\", \"rabbit@10.0.2.147\"]'" }
      ]
    }
  ])
}

# --- 2. ECS Service (Despliegue de 3 réplicas) ---
resource "aws_ecs_service" "rabbitmq" {
  name                = "rabbitmq-service"
  cluster             = aws_ecs_cluster.rabbitmq_cluster.id # Usar el nombre de recurso de ecs.tf
  task_definition     = aws_ecs_task_definition.rabbitmq.arn
  desired_count       = 3 # Clúster de 3 nodos
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"

  # Configuración de red para Fargate
  network_configuration {
    security_groups  = [aws_security_group.rabbitmq.id]                   # Usar el SG de RabbitMQ de security_groups.tf
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id] # Usar subredes privadas
    assign_public_ip = false                                              # Las tareas en subredes privadas no necesitan IP pública. Usarán NAT GW para salida.
  }
}
