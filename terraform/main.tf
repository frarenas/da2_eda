# Configuración del proveedor de AWS
provider "aws" {
  region = var.aws_region
}

# --- 1. VPC (Virtual Private Cloud) ---
resource "aws_vpc" "citypass_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Habilitar soporte DNS
  enable_dns_hostnames = true # CRÍTICO para Fargate/CloudMap
  instance_tenancy     = "default"

  tags = {
    Name                 = "citypass-vpc"
    RabbitMQ_Cluster_DNS = "rabbit-cluster.citypass.local"
  }
}

# --- 2. Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.citypass_vpc.id

  tags = {
    Name = "citypass-igw"
  }
}

# --- 3. Subredes Públicas y Privadas (HA en 2 AZs) ---
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.citypass_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # Para el Load Balancer y NAT Gateway

  tags = { Name = "Public-A" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.citypass_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = { Name = "Public-B" }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.citypass_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false # No asigna IPs públicas a las tareas de Fargate

  tags = { Name = "Private-A" }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.citypass_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = { Name = "Private-B" }
}

# --- 4. NAT Gateways (Una por AZ para HA) ---

resource "aws_eip" "nat_a_eip" {
  tags = { Name = "nat-a-eip" }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a_eip.id
  subnet_id     = aws_subnet.public_a.id

  tags       = { Name = "NAT-Gateway-A" }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat_b_eip" {
  tags = { Name = "nat-b-eip" }
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b_eip.id
  subnet_id     = aws_subnet.public_b.id

  tags       = { Name = "NAT-Gateway-B" }
  depends_on = [aws_internet_gateway.igw]
}

# --- 5. Tablas de Rutas ---

# Tabla de Rutas Pública (acceso a Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.citypass_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "Public-Route-Table" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Tabla de Rutas Privada A (acceso a NAT Gateway A)
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.citypass_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = { Name = "Private-Route-Table-A" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

# Tabla de Rutas Privada B (acceso a NAT Gateway B)
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.citypass_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }

  tags = { Name = "Private-Route-Table-B" }
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# --- 6. Data Source para obtener AZs disponibles ---
data "aws_availability_zones" "available" {
  state = "available"
}
