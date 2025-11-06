resource "null_resource" "import_rabbit_definitions" {
  # Re-run when the ALB DNS or admin credentials change
  triggers = {
    alb_dns = aws_lb.alb.dns_name
    user    = var.rabbitmq_admin_user
  }

  # Ensure ALB and ECS service are ready before attempting the import
  depends_on = [aws_lb.alb, aws_ecs_service.rabbitmq]

  provisioner "local-exec" {
    command     = <<EOF
#!/usr/bin/env bash
set -e
ALB=${aws_lb.alb.dns_name}
USER=${var.rabbitmq_admin_user}
PASS=${var.rabbitmq_admin_pass}
DEFS_FILE="${path.module}/../rabbit-common/definitions.json"

echo "Waiting for RabbitMQ management endpoint at http://$ALB to become available..."
for i in {1..30}; do
  if curl -sS -o /dev/null -u "$USER:$PASS" "http://$ALB/api/overview"; then
    echo "Management API reachable"
    break
  fi
  echo "Waiting... ($i)"
  sleep 5
done

echo "Posting definitions from $DEFS_FILE to http://$ALB/api/definitions"
curl -v -u "$USER:$PASS" -H "content-type: application/json" -X POST "http://$ALB/api/definitions" --data-binary @"$DEFS_FILE"
EOF
    interpreter = ["/bin/bash", "-c"]
  }
}
