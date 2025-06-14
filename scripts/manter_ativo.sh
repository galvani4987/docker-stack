#!/bin/bash
# Script para manter os serviços do Docker Compose ativos.
# Executado via cron.

# Navegar para o diretório do docker-compose.yml
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$( dirname "$SCRIPT_DIR" )" # Assume scripts/ está um nível abaixo do projeto

cd "$PROJECT_DIR" || { echo "Falha ao navegar para o diretório do projeto $PROJECT_DIR. Saindo."; exit 1; }

# Log de início
echo "--------------------------------------"
echo "Executando manter_ativo.sh em: $(date)"
echo "Verificando serviços no diretório: $(pwd)"

# Lista de serviços críticos a serem verificados.
# Adicionar futuros serviços críticos aqui conforme são adicionados ao docker-compose.yml.
SERVICES_TO_CHECK=(
  "postgres"
  "caddy"
  "n8n"
  "authentik-postgres"
  "authentik-redis"
  "authentik-server"
  "authentik-worker"
  # "homer"
  # "redis"
  # "authelia"
)

echo "Serviços a serem verificados: ${SERVICES_TO_CHECK[*]}"
echo ""

SERVICES_RESTARTED=0

for SERVICE_NAME in "${SERVICES_TO_CHECK[@]}"; do
  echo "Verificando serviço: $SERVICE_NAME"

  RUNNING_CONTAINER_ID=$(docker compose ps --status running -q "$SERVICE_NAME" 2>/dev/null)

  if [ -z "$RUNNING_CONTAINER_ID" ]; then
    echo "Serviço $SERVICE_NAME NÃO está rodando ou não foi encontrado."
    echo "Tentando iniciar/reiniciar $SERVICE_NAME..."

    docker compose up -d "$SERVICE_NAME"

    NEW_RUNNING_CONTAINER_ID=$(docker compose ps --status running -q "$SERVICE_NAME" 2>/dev/null)
    if [ -z "$NEW_RUNNING_CONTAINER_ID" ]; then
      echo "ERRO: Falha ao iniciar o serviço $SERVICE_NAME."
    else
      echo "Serviço $SERVICE_NAME iniciado com sucesso (Container ID: $NEW_RUNNING_CONTAINER_ID)."
      SERVICES_RESTARTED=$((SERVICES_RESTARTED + 1))
    fi
  else
    echo "Serviço $SERVICE_NAME está rodando (Container ID: $RUNNING_CONTAINER_ID)."
  fi
  echo "" # Linha em branco para separar logs de serviços
done

if [ "$SERVICES_RESTARTED" -gt 0 ]; then
  echo "$SERVICES_RESTARTED serviço(s) foram reiniciados."
else
  echo "Todos os serviços verificados já estavam rodando."
fi

echo "Verificação concluída em: $(date)"
echo "--------------------------------------"
echo ""

exit 0
