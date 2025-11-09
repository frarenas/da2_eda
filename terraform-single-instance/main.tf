# Configuración del proveedor
provider "aws" {
  region = var.aws_region
}

# --- 0. JSON de Definiciones (Archivo Externo) ---
locals {
  # 1. Lee el contenido del archivo definitions.json.
  # Asegúrese de que 'definitions.json' esté en el mismo directorio.
  # Use the shared rabbit-common folder (sibling to this folder)
  raw_definitions_json = file("../rabbit-common/definitions.json")
  # Also load a rabbitmq.conf from the rabbit-common folder for container config
  raw_rabbitmq_conf = file("../rabbit-common/rabbitmq.conf")

  # 2. Eliminamos saltos de línea si alguna parte se usara como una variable aplanada.
  rabbitmq_definitions_json = replace(replace(replace(local.raw_definitions_json, "\n", ""), "\r", ""), "\t", "")
}

# --- 1. Red Minimalista (VPC, IGW, Subnet y Route Table) ---

resource "aws_vpc" "simple_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "simple-rabbitmq-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.simple_vpc.id
  tags   = { Name = "simple-igw" }
}

# Data Source para obtener la primera AZ
data "aws_availability_zones" "available" {
  state = "available"
}

# Subred Pública Única (lo más simple)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.simple_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # Fargate necesita IP pública en esta configuración

  tags = { Name = "Simple-Public-A" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.simple_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Public-Route-Table" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

# --- 2. Security Group (SG) ---

resource "aws_security_group" "rabbitmq_sg" {
  name        = "simple-rabbitmq-sg"
  description = "Permite acceso a Management (15672) y AMQP (5672)"
  vpc_id      = aws_vpc.simple_vpc.id

  # Acceso Ingress (Entrada) - PUERTOS CLAVE
  ingress {
    description = "RabbitMQ Management UI"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # NOTA: Por simplicidad, es abierto. Reemplace con su IP por seguridad.
  }

  ingress {
    description = "RabbitMQ AMQP"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # NOTA: Por simplicidad, es abierto. Reemplace con su IP por seguridad.
  }

  # Regla de Salida (Egress) - Permite tráfico saliente
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 3. ECS Cluster ---

resource "aws_ecs_cluster" "citypass" {
  name = "simple-rabbitmq-cluster"
}

# --- 4. IAM Role para la Tarea (Task Execution Role) ---

resource "aws_iam_role" "ecs_task_execution_role" {
  count              = var.create_task_execution_role ? 1 : 0
  name               = "ecs-task-execution-role-simple"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  count      = var.create_task_execution_role ? 1 : 0
  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- 5. Task Definition (Fargate) ---

resource "aws_ecs_task_definition" "rabbitmq" {
  family                   = "simple-rabbitmq-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024

  execution_role_arn = var.create_task_execution_role ? aws_iam_role.ecs_task_execution_role[0].arn : var.execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "rabbitmq-single",
      image     = "rabbitmq:4-management",
      essential = true,
      # TRUCO: El comando usa el contenido aplanado del archivo definitions.json.
      # Nota la necesidad de las comillas simples '...' para el string JSON en el shell.
      command = [
        "/bin/sh",
        "-c",
        # Use base64 encoding to avoid shell quoting/breakage when injecting JSON and conf into the container
        "echo '${base64encode(local.raw_definitions_json)}' | base64 -d > /etc/rabbitmq/definitions.json && echo '${base64encode(local.raw_rabbitmq_conf)}' | base64 -d > /etc/rabbitmq/rabbitmq.conf && rabbitmq-server"
      ],
      environment = [
        {
          name  = "RABBITMQ_ERLANG_COOKIE",
          value = "SECRETSIMPLECOOKIE"
        }
      ],
      healthCheck = {
        command    = ["CMD-SHELL", "rabbitmq-diagnostics -q status || exit 1"]
        interval   = 30
        timeout    = 5
        retries    = 5
        startPeriod = 60
      },
      portMappings = [
        {
          containerPort = 5672,
          hostPort      = 5672
        },
        {
          containerPort = 15672,
          hostPort      = 15672
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.rabbitmq_logs.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "rabbitmq"
        }
      }
    }
  ])

  # Ensure the CloudWatch log group exists before the task definition is registered
  depends_on = [aws_cloudwatch_log_group.rabbitmq_logs]

}

# CloudWatch Log Group para la tarea
resource "aws_cloudwatch_log_group" "rabbitmq_logs" {
  name              = "/ecs/simple-rabbitmq"
  retention_in_days = 7
}

# --- 6. ECS Service ---

resource "aws_ecs_service" "rabbitmq" {
  name            = "simple-rabbitmq-service"
  cluster         = aws_ecs_cluster.citypass.id
  task_definition = aws_ecs_task_definition.rabbitmq.arn
  desired_count   = 1 # Una sola instancia, como se solicitó
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet.id]
    security_groups  = [aws_security_group.rabbitmq_sg.id]
    assign_public_ip = true # Necesario para poder acceder
  }
}