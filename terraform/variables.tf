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