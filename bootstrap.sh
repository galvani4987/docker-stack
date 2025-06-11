#!/bin/bash

echo "--- Iniciando Bootstrap do Servidor ---"

# Garante que o script está sendo executado com privilégios de root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute com sudo: sudo bash bootstrap.sh"
  exit 1
fi

echo "--> Atualizando pacotes do sistema..."
apt-get update

echo "--> Instalando dependências do host (Cockpit, htop, Docker se necessário)..."
# Adiciona Docker aqui para garantir que ele esteja presente
if ! command -v docker &> /dev/null
then
    echo "Docker não encontrado, instalando..."
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
fi
apt-get install -y cockpit htop docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "--> Habilitando serviço do Cockpit..."
systemctl enable --now cockpit.socket

echo "--> Configurando o ambiente do Docker Stack..."
# Verifica se o .env existe. Se não, cria a partir do template.
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "Arquivo .env criado a partir de .env.example."
    echo "!!! AÇÃO NECESSÁRIA: Edite o arquivo .env e preencha suas senhas e segredos."
  else
    echo "AVISO: .env.example não encontrado. Pulando criação do .env."
  fi
else
  echo "Arquivo .env já existe. Nenhuma ação necessária."
fi

# Dá permissão de execução ao próprio script
chmod +x bootstrap.sh

echo "--- Bootstrap Concluído ---"
