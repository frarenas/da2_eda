// Application Load Balancer to expose RabbitMQ Management UI
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.citypass_vpc.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "alb" {
  name               = "citypass-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "citypass-alb"
  }
}

resource "aws_lb_target_group" "rabbit_tg" {
  name        = "rabbitmq-tg"
  port        = 15672
  protocol    = "HTTP"
  vpc_id      = aws_vpc.citypass_vpc.id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    path     = "/"
    interval = 30
    timeout  = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rabbit_tg.arn
  }
}
