resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = aws_vpc.citypass_vpc.id

  ingress {
    description     = "Allow NFS from RabbitMQ tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.rabbitmq.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_file_system" "rabbit" {
  creation_token = "citypass-rabbitmq-efs"
  tags = {
    Name = "citypass-rabbitmq-efs"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Create mount targets in the public subnets (one per AZ)
resource "aws_efs_mount_target" "mt_a" {
  file_system_id  = aws_efs_file_system.rabbit.id
  subnet_id       = aws_subnet.public_a.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "mt_b" {
  file_system_id  = aws_efs_file_system.rabbit.id
  subnet_id       = aws_subnet.public_b.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Access point to ensure the /coord directory exists and permissions are set
resource "aws_efs_access_point" "coord" {
  file_system_id = aws_efs_file_system.rabbit.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/coord"
    creation_info {
      owner_uid = 1000
      owner_gid = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name = "citypass-rabbitmq-coord-ap"
  }
}
