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
      # Mount the EFS volume into the container for coordination only (/shared)
      # NOTE: for this quick PoC we use EFS as a coordination directory. We DO NOT
      # mount the same directory as RabbitMQ data to avoid corruption. Each node
      # will use its own ephemeral data dir. A bootstrap script will use /shared
      # to elect/join a leader.
      mountPoints = [
        {
          sourceVolume  = "rabbitmq-coord"
          containerPath = "/shared"
          readOnly      = false
        }
      ]

      # Start/cluster bootstrap script: set a predictable node name, start RabbitMQ,
      # wait for management API and then either become leader or join existing leader
      command = ["/bin/sh", "-c",
        "IP=$(hostname -I 2>/dev/null | awk '{print $1}'); if [ -z \"$IP\" ]; then IP=$(hostname -i || hostname); fi; export RABBITMQ_NODENAME=\"rabbit@$IP\"; echo Node name=$RABBITMQ_NODENAME; rabbitmq-server -detached || (echo start-failed && exit 1); for i in $(seq 1 30); do if curl -sS -u \"$RABBITMQ_DEFAULT_USER:$RABBITMQ_DEFAULT_PASS\" http://127.0.0.1:15672/api/overview >/dev/null 2>&1; then break; fi; sleep 2; done; COORD_DIR=/shared/cluster; mkdir -p $COORD_DIR; JOIN_LOG=$COORD_DIR/join.log; echo \"Bootstrap start $(date)\" | tee -a $JOIN_LOG; if [ -f $COORD_DIR/leader ]; then LEADER=$(cat $COORD_DIR/leader); if [ \"$LEADER\" != \"$IP\" ]; then echo \"Joining cluster $LEADER\" | tee -a $JOIN_LOG; for attempt in 1 2 3 4 5; do echo \"--- attempt $attempt ---\" | tee -a $JOIN_LOG; rabbitmqctl stop_app >> $JOIN_LOG 2>&1 || echo \"stop_app failed rc=$?\" | tee -a $JOIN_LOG; rabbitmqctl join_cluster rabbit@\"$LEADER\" >> $JOIN_LOG 2>&1 && rc=$? || rc=$?; echo \"join_cluster rc=$rc\" | tee -a $JOIN_LOG; rabbitmqctl start_app >> $JOIN_LOG 2>&1 || echo \"start_app failed rc=$?\" | tee -a $JOIN_LOG; if [ $rc -eq 0 ]; then echo \"join succeeded\" | tee -a $JOIN_LOG; break; else echo \"join failed, retrying\" | tee -a $JOIN_LOG; sleep 2; fi; done; fi; else echo \"$IP\" > $COORD_DIR/leader; echo Became leader | tee -a $JOIN_LOG; fi; sleep 2; echo \"=== cluster_status ===\" | tee -a $JOIN_LOG; rabbitmqctl cluster_status >> $JOIN_LOG 2>&1 || echo \"cluster_status failed rc=$?\" | tee -a $JOIN_LOG; cat $JOIN_LOG; tail -F /var/log/rabbitmq/*"
      ]
    }
  ])

  # Define the EFS-backed volume for the task
  volume {
    name = "rabbitmq-coord"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.rabbit.id
      # Use an EFS Access Point so the /coord directory exists and permissions are correct
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.coord.id
      }
    }
  }
}

# --- 2. ECS Service (Despliegue de 3 réplicas) ---
resource "aws_ecs_service" "rabbitmq" {
  name                = "rabbitmq-service"
  cluster             = aws_ecs_cluster.rabbitmq_cluster.id # Usar el nombre de recurso de ecs.tf
  task_definition     = aws_ecs_task_definition.rabbitmq.arn
  desired_count       = 3 # Scale to 3 replicas for clustering
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
