#!/bin/bash
echo "--- Iniciando Bootstrap do Servidor ---"

# Verificar privilégios
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute com sudo: sudo bash $0"
  exit 1
fi

# Atualizar sistema
echo "> Atualizando pacotes..."
apt-get update
apt-get upgrade -y

# Instalar dependências essenciais
echo "> Instalando dependências..."
apt-get install -y git curl make htop ufw

# Configurar UFW
echo "> Configurando firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw -f enable

# Instalar Docker
if ! command -v docker &> /dev/null; then
  echo "> Instalando Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# Instalar Docker Compose
if ! docker compose version &> /dev/null; then
  echo "> Instalando Docker Compose Plugin..."
  apt-get install -y docker-compose-plugin
fi

# Configurar usuário Docker
echo "> Configurando usuário Docker..."
usermod -aG docker ubuntu

# Instalar Cockpit
echo "> Instalando Cockpit..."
apt-get install -y cockpit
systemctl enable --now cockpit.socket

# Criar estrutura de diretórios
echo "> Criando estrutura de diretórios..."
mkdir -p {config,data,scripts}

# Configurar ambiente
echo "> Configurando ambiente..."
[ ! -f .env ] && cp .env.example .env 2>/dev/null || echo ".env já existe"
chmod +x *.sh scripts/*.sh 2>/dev/null

echo "--- Bootstrap Concluído ---"
echo "1. Edite o arquivo .env com suas configurações"
echo "2. Execute 'docker compose up -d' para iniciar os serviços"
