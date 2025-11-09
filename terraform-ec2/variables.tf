variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Optional EC2 key pair name (leave empty to skip)"
  type        = string
  default     = ""
}

variable "allowed_cidr" {
  description = "CIDR allowed to access service ports (SSH, RabbitMQ, Prometheus, Grafana, Postgres). Default 0.0.0.0/0 for testing."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "subnet_id" {
  description = "Optional subnet id to launch the instance into. If empty, the first subnet in the default VPC will be used when available."
  type        = string
  default     = ""
}

variable "created_subnet_cidr" {
  description = "CIDR block to create a subnet in the default VPC when no subnets exist (only used when needed)."
  type        = string
  default     = "172.31.200.0/24"
}
