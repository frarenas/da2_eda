variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "execution_role_arn" {
  description = "ARN of an existing IAM role to use as the ECS task execution role. If empty and create_task_execution_role=true, Terraform will create one."
  type        = string
  default     = "arn:aws:iam::767397732475:role/LabRole"
}

variable "create_task_execution_role" {
  description = "Whether Terraform should create an ECS task execution role. Set to false to use an existing role via execution_role_arn."
  type        = bool
  default     = false
}
