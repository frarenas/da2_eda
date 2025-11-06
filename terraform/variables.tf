variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "El bloque CIDR de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "create_task_execution_role" {
  description = "If true, Terraform will create an ECS task execution role. Set to false for restricted accounts (e.g. AWS Academy)."
  type        = bool
  default     = false
}

variable "execution_role_arn" {
  description = "ARN of an existing ECS task execution role to use when not creating one."
  type        = string
  default     = ""
}

variable "rabbitmq_admin_user" {
  description = "Default RabbitMQ admin user to create (used for management and importing definitions)."
  type        = string
  default     = "admin"
}

variable "rabbitmq_admin_pass" {
  description = "Default RabbitMQ admin password. Change this in production."
  type        = string
  default     = "ChangeMe123!"
}