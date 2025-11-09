#!/bin/bash
# Este script está optimizado para ejecutarse como EC2 User Data en una AMI de Ubuntu.
# Se encarga de instalar Docker, clonar el repositorio y levantar los contenedores (RabbitMQ).

# --- 1. Actualizar sistema e instalar prerequisitos ---
echo "--- 1. Actualizando sistema e instalando prerequisitos (apt-get) ---"
# Aseguramos que git esté instalado para la clonación
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common git docker-compose-plugin

# --- 2. Instalar Docker Engine (siguiendo el método oficial de Docker) ---
echo "--- 2. Instalando Docker Engine ---"

# Add Docker's GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add the Docker repository to APT sources
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and client
apt update
apt install -y docker-ce docker-ce-cli containerd.io

# --- 3. Habilitar y arrancar Docker Service ---
echo "--- 3. Habilitando y arrancando Docker Service ---"

# Habilitar Docker para que se inicie automáticamente en boot
systemctl enable docker
# Iniciar el servicio inmediatamente
systemctl start docker

# El User Data se ejecuta como root. Si desea que el usuario 'ubuntu'
# pueda usar docker sin sudo, ejecute el siguiente comando.
usermod -aG docker ubuntu

# --- 4. Clonar el Repositorio de la Aplicación ---
echo "--- 4. Clonando el repositorio EDA ---"

# Aseguramos que el directorio principal exista
mkdir -p /home/ubuntu/EDA
# Clonar el repositorio
git clone https://github.com/frarenas/da2_eda.git /home/ubuntu/EDA

# --- 5. Desplegar y Levantar el Contenedor de RabbitMQ ---
echo "--- 5. Desplegando RabbitMQ con Docker Compose ---"

# Moverse al directorio donde está el docker-compose.yml (asumiendo que está en la raíz del repo)
cd /home/ubuntu/EDA

# Levantar los servicios definidos en el docker-compose.yml en modo detached (-d)
# Como ya instalamos docker-compose-plugin, usamos 'docker compose'
docker compose up -d

echo "--- Script de User Data Finalizado ---"