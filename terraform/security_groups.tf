# Este archivo contiene las definiciones de los grupos de seguridad (Security Groups)

# --- 1. SG-LB-Access (Para el tráfico público a través del Load Balancer) ---
resource "aws_security_group" "lb_access" {
  name        = "lb-access-sg"
  description = "Allows public internet access for the ALB to common ports"
  vpc_id      = aws_vpc.citypass_vpc.id

  # Reglas de Entrada (Permitir acceso público a dashboards/mgmt)
  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "RabbitMQ Management UI"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla de Salida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 2. SG-RabbitMQ (Para el clustering y AMQP) ---
resource "aws_security_group" "rabbitmq" {
  name        = "rabbitmq-sg"
  description = "Allows RabbitMQ clustering (25672) and AMQP (5672) from self"
  vpc_id      = aws_vpc.citypass_vpc.id

  # Reglas de Entrada (AMQP)
  ingress {
    description = "Cluster/Internal traffic (Erlang, AMQP, Management) from same security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # TCP, UDP, ICMP (all)
    self        = true # Self-reference for cluster communication
  }

  # Reglas de Entrada (Erlang)
  ingress {
    description = "Erlang Port (25672) - Clustering interno"
    from_port   = 25672
    to_port     = 25672
    protocol    = "tcp"
    self        = true # Auto-referencia para comunicación de cluster
  }

  # Permitir que Prometheus (SG `metrics`) scrappee RabbitMQ en el puerto de métricas
  ingress {
    description     = "Prometheus scraping (15692) from metrics SG"
    from_port       = 15692
    to_port         = 15692
    protocol        = "tcp"
    security_groups = [aws_security_group.metrics.id]
  }
  # Allow ALB to reach RabbitMQ management UI (15672)
  ingress {
    description     = "Allow ALB to access RabbitMQ Management UI"
    from_port       = 15672
    to_port         = 15672
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Public access: allow management UI and AMQP directly from the internet
  ingress {
    description = "Public access to RabbitMQ Management UI"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Public access to RabbitMQ AMQP port"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla de Salida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Permite salida a Internet/VPC
  }
}

# --- 3. SG-Postgres (Base de Datos) ---
resource "aws_security_group" "postgres" {
  name        = "postgres-sg"
  description = "Allows Postgres access only from RabbitMQ/other services"
  vpc_id      = aws_vpc.citypass_vpc.id

  # Regla de Entrada (Solo desde RabbitMQ y Prometheus)
  ingress {
    description     = "Postgres from RabbitMQ nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rabbitmq.id]
  }

  ingress {
    description = "Postgres from Prometheus/Grafana (if needed for metrics)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # Requiere que SG-Metrics exista antes de la asociación (se omite el depends_on implícito)
    security_groups = [aws_security_group.metrics.id]
  }

  # Regla de Salida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 4. SG-Metrics (Prometheus / Grafana) ---
resource "aws_security_group" "metrics" {
  name        = "metrics-sg"
  description = "Allows internal communication for monitoring services"
  vpc_id      = aws_vpc.citypass_vpc.id

  # Regla de Entrada (Permitir que el ALB hable con Grafana/Prometheus)
  ingress {
    description     = "Access from ALB (for 3000/9090) via SG-LB-Access"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.lb_access.id]
  }

  # Regla de Entrada (Permite que Prometheus acceda a RabbitMQ en el puerto de métricas)
  # Nota: las reglas de scraping deben permitir que Prometheus (SG `metrics`) se conecte
  # a RabbitMQ; la regla se define en el SG `rabbitmq` para abrir el puerto 15692 desde `metrics`.

  # Regla de Salida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
