#!/bin/bash
echo "=== Iniciando Limpeza do Servidor ==="

# 1. Remover Docker e componentes
echo "> Removendo Docker..."
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker /etc/docker
sudo rm -f /etc/apparmor.d/docker
sudo groupdel docker 2>/dev/null

# 2. Resetar UFW
echo "> Resetando Firewall..."
sudo ufw disable
sudo ufw reset
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw -f enable

# 3. Limpar pacotes e arquivos temporários
echo "> Limpando sistema..."
sudo apt autoremove -y
sudo apt clean
sudo rm -rf /tmp/* /var/tmp/*

# 4. Verificar limpeza
echo "> Verificando limpeza:"
docker --version 2>/dev/null || echo "Docker removido com sucesso"
sudo ufw status

echo "=== Limpeza concluída! O servidor está pronto para nova configuração ==="
