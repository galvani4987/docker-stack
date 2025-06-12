# Tutorial: Configurando o n8n

Este tutorial guia você pela configuração, implantação e verificação do n8n, uma ferramenta de automação de fluxos de trabalho, como parte do projeto Docker Stack VPS.

## Pré-requisitos

1.  **Serviços Essenciais Rodando:** Certifique-se de que os serviços `postgres` e `caddy` já estejam configurados e rodando, conforme as Fases 1.A e 1.B do [ROADMAP.md](../../ROADMAP.md).
2.  **Variáveis de Ambiente Base:** As variáveis de ambiente para PostgreSQL (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`) devem estar definidas no arquivo `.env` na raiz do projeto.

## 1. Variáveis de Ambiente para n8n

Adicione as seguintes variáveis específicas do n8n ao seu arquivo `.env`. Se já existirem dos passos anteriores do roadmap, verifique se estão corretas:

```env
# Configurações do n8n
N8N_DB_TYPE=postgresdb
N8N_DB_POSTGRESDB_HOST=postgres
N8N_DB_POSTGRESDB_PORT=5432
N8N_DB_POSTGRESDB_DATABASE=${POSTGRES_DB}    # Reutiliza a variável do PostgreSQL
N8N_DB_POSTGRESDB_USER=${POSTGRES_USER}      # Reutiliza a variável do PostgreSQL
N8N_DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD} # Reutiliza a variável do PostgreSQL
# N8N_DB_POSTGRESDB_SCHEMA=public             # Opcional, 'public' é o padrão

# URL pública que o n8n usará para webhooks.
# Certifique-se de que seu DNS para n8n.galvani4987.duckdns.org aponta para o IP do seu servidor.
N8N_WEBHOOK_URL=https://n8n.galvani4987.duckdns.org/

# Recomendado para evitar problemas de permissão com o volume de dados do n8n.
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false

# Habilita a execução de sub-processos para certos nós (ex: Execute Command).
N8N_RUNNERS_ENABLED=true

# Chave de criptografia para dados sensíveis (credenciais).
# Gere uma string aleatória segura de 32 caracteres. Por exemplo, no seu terminal:
#   openssl rand -hex 32
# DESCOMENTE E DEFINA ESTA CHAVE SE NÃO MONTAR O VOLUME /home/node/.n8n (veja seção Docker Compose)
# N8N_ENCRYPTION_KEY=sua_chave_de_criptografia_segura_aqui

# Timezone para o n8n (opcional, mas recomendado)
# Use o formato de timezone do seu servidor, ex: America/Sao_Paulo, Europe/Berlin
GENERIC_TIMEZONE=America/Sao_Paulo
TZ=America/Sao_Paulo
```

**Nota sobre `N8N_ENCRYPTION_KEY`:**
A documentação oficial do n8n recomenda persistir o diretório `/home/node/.n8n` (onde a chave de criptografia é gerada e armazenada) usando um volume Docker. Se você seguir a recomendação de adicionar o volume na seção Docker Compose abaixo (altamente recomendado), definir `N8N_ENCRYPTION_KEY` explicitamente é opcional (o n8n gerará uma). Se você *não* montar o volume, definir esta chave é **obrigatório** para que as credenciais não sejam perdidas a cada reinício do container.

**Recomendação de Usuário PostgreSQL Dedicado (Opcional Avançado):**
Para maior segurança, em vez de usar o usuário administrador do PostgreSQL (`${POSTGRES_USER}`), você pode criar um usuário e banco de dados dedicados para o n8n no PostgreSQL. O `docker-compose.yml` oficial do n8n-hosting sugere um script `init-data.sh` para isso. Para este projeto, manteremos o uso do usuário principal do PostgreSQL para simplificar, mas esteja ciente dessa prática recomendada para ambientes de produção mais rigorosos.

## 2. Configuração no `docker-compose.yml`

Modifique o serviço `n8n` no seu arquivo `docker-compose.yml` para incluir o volume de dados e ajustar `depends_on`:

```yaml
services:
  # ... outros serviços como postgres e caddy ...

  n8n:
    image: n8nio/n8n:latest  # Você pode fixar uma versão específica, ex: n8nio/n8n:1.97.1
    container_name: n8n
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - DB_TYPE=${N8N_DB_TYPE}
      - DB_POSTGRESDB_HOST=${N8N_DB_POSTGRESDB_HOST}
      - DB_POSTGRESDB_PORT=${N8N_DB_POSTGRESDB_PORT}
      - DB_POSTGRESDB_USER=${N8N_DB_POSTGRESDB_USER}
      - DB_POSTGRESDB_PASSWORD=${N8N_DB_POSTGRESDB_PASSWORD}
      - DB_POSTGRESDB_DATABASE=${N8N_DB_POSTGRESDB_DATABASE}
      # - DB_POSTGRESDB_SCHEMA=${N8N_DB_POSTGRESDB_SCHEMA:-public} # Descomente se usar schema específico
      - N8N_WEBHOOK_URL=${N8N_WEBHOOK_URL}
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=${N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS}
      - N8N_RUNNERS_ENABLED=${N8N_RUNNERS_ENABLED}
      - N8N_HOST=n8n # Nome do host interno para o n8n se comunicar consigo mesmo se necessário
      # - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY} # Descomente se definido no .env e não usando volume para /home/node/.n8n
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - TZ=${TZ}
    networks:
      - app-network
    volumes:
      - n8n_data:/home/node/.n8n # ESSENCIAL para persistir dados e chave de criptografia
    depends_on:
      postgres:
        condition: service_started # Ou 'service_healthy' se o healthcheck do postgres estiver configurado e funcionando
        # Para usar 'service_healthy', o serviço postgres precisa de uma seção 'healthcheck'.
        # Exemplo de healthcheck para postgres (já presente no docker-compose.yml do n8n-hosting):
        # healthcheck:
        #   test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
        #   interval: 5s
        #   timeout: 5s
        #   retries: 10

volumes:
  # ... outros volumes como postgres_data, caddy_data, caddy_config ...
  n8n_data: # Define o volume n8n_data
```

**Principais Alterações:**
*   **`volumes:` Adicionado `n8n_data:/home/node/.n8n`.** Isso garante que os dados do n8n, incluindo fluxos de trabalho, credenciais e a chave de criptografia, sejam persistidos.
*   **`volumes:` Adicionado `n8n_data:` na seção global de volumes no final do arquivo.**
*   **`depends_on.postgres.condition:`** Alterado para `service_started` para garantir que o PostgreSQL tenha iniciado antes do n8n. Se o seu serviço PostgreSQL tiver um `healthcheck` configurado (como no exemplo do `n8n-hosting`), você pode usar `service_healthy` para uma verificação mais robusta. O `docker-compose.yml` base do projeto não define um healthcheck para o `postgres` por padrão.

## 3. Configuração do Caddy (Proxy Reverso)

A configuração do Caddy para o n8n já está delineada no `ROADMAP.md` (Fase 2.A.2) e no arquivo `config/Caddyfile` do projeto. Ela deve ser semelhante a:

```caddy
n8n.galvani4987.duckdns.org {
    reverse_proxy n8n:5678 {
        # Adiciona headers importantes para o proxy reverso
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    # A autenticação via Authelia será adicionada posteriormente (Fase 3.B)
    # forward_auth http://authelia:9091 {
    #   uri /authelia
    #   copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    # }
}
```
Verifique se o seu `config/Caddyfile` contém esta entrada ou uma similar. O `email` para certificados SSL já deve estar configurado globalmente no seu Caddyfile.

## 4. Implantação

1.  **Certifique-se de que o DNS está configurado:** O subdomínio `n8n.galvani4987.duckdns.org` deve estar apontando para o IP do seu servidor.
2.  **Inicie/Atualize os serviços:**
    No diretório raiz do projeto (onde está o `docker-compose.yml`), execute:
    ```bash
    docker compose up -d n8n
    ```
    Se o Caddy precisar ser recarregado para pegar novas configurações (geralmente não necessário para este tipo de mudança se o Caddy já estiver proxying para o serviço `n8n` por nome), você pode recarregá-lo:
    ```bash
    docker compose exec -w /etc/caddy caddy caddy reload
    # Ou reinicie o Caddy: docker compose restart caddy
    ```

## 5. Verificação

1.  **Logs do Docker:** Verifique os logs do n8n para quaisquer erros durante a inicialização:
    ```bash
    docker compose logs n8n
    ```
    Procure por mensagens indicando que o n8n iniciou e está conectado ao banco de dados.
2.  **Acesso via Navegador:** Abra `https://n8n.galvani4987.duckdns.org` no seu navegador.
    *   Você deverá ver a interface de configuração inicial do n8n para criar uma conta de administrador.
    *   Crie sua conta de administrador.
3.  **Teste de Funcionalidade (Opcional):**
    *   Crie um fluxo de trabalho simples (ex: um Webhook que responde com "Hello World") para testar.
    *   Verifique se os fluxos de trabalho são salvos corretamente (indicando que a persistência de dados e a conexão com o banco de dados estão funcionando).

## 6. Próximos Passos no Roadmap

Com o n8n implantado e verificado:
*   Marque as etapas "2.A.3. Implantação" e "2.A.4. Verificação" como `[✅]` no `ROADMAP.md`.
*   Prossiga para a configuração do Homer (Fase 2.B) ou outros serviços conforme o roadmap.
*   Lembre-se que a integração com Authelia para o n8n será feita na Fase 3.B.

Este tutorial cobriu a configuração e implantação inicial do n8n. Consulte a [documentação oficial do n8n](https://docs.n8n.io/) para funcionalidades avançadas e troubleshooting.
```
