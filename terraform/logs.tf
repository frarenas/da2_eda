resource "aws_cloudwatch_log_group" "rabbitmq" {
  name              = "/ecs/rabbitmq"
  retention_in_days = 7

  tags = {
    Name = "ecs-rabbitmq-logs"
  }
}
