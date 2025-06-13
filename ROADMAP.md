# Roadmap de Implantação Detalhado

**Estado Atual:** Fases 0 e 1 concluídas. Fase 2.A (n8n Configuração) parcialmente concluída. Fase 4 (Cockpit Instalação) parcialmente concluída. Implementação do script `manter_ativo.sh` concluída.

**Última Atualização:** 17 de Julho de 2024

**Domínio Base:** [`galvani4987.duckdns.org`](https://galvani4987.duckdns.org)

**Convenção de Subdomínio:** `aplicativo.galvani4987.duckdns.org` (Ex: [`n8n.galvani4987.duckdns.org`](https://n8n.galvani4987.duckdns.org))

**Legenda:** 

* `[ ]` - Pendente

* `[▶️]` - Em Andamento

* `[✅]` - Concluído

## Fase 0: Preparação do Ambiente ✅

*Configuração inicial do servidor e estrutura do projeto*

* \[✅\] **0.1. Pesquisa:** Melhores práticas para organização de projetos Docker

* \[✅\] **0.2. Configuração:** 

  * \[✅\] Repositório clonado em `/home/ubuntu/docker-stack`

  * \[✅\] Arquivo `.gitignore` criado com entrada `.env`

  * \[✅\] Arquivo `.env` criado (template)

  * \[✅\] `docker-compose.yml` com estrutura inicial

  * \[✅\] Scripts criados e refinados:
    * `bootstrap.sh` para configuração inicial (revisado e melhorado)
    * `clean-server.sh` para reset completo (revisado e melhorado)
    * `manter_ativo.sh` para monitoramento de serviços (implementado)
  * \[✅\] `README.md` atualizado com instruções

* \[✅\] **0.3. Verificação:**
  * \[✅\] Estrutura de arquivos confirmada
  * \[✅\] Cron job para `manter_ativo.sh` configurado. Instrução verificada (conforme README.md): Editar crontab com `crontab -e` e adicionar a linha: `0 * * * * /home/ubuntu/docker-stack/scripts/manter_ativo.sh`.

## Fase 1: A Fundação (Proxy Reverso e Banco de Dados) \[✅\]

*Configuração do PostgreSQL e Caddy*

### 1.A - Serviço PostgreSQL \[✅\]

* \[✅\] **1.A.1. Pesquisa:** Imagem oficial PostgreSQL (tag: `16-alpine`)

* \[✅\] **1.A.2. Configuração:** 
    * \[✅\] Consulte o [Tutorial de Configuração do PostgreSQL](docs/setup_postgresql.md) para um guia detalhado da sua configuração neste projeto.
  * \[✅\] Variáveis adicionadas ao `.env`:

  ```env
  POSTGRES_DB=main_db
  POSTGRES_USER=admin
  POSTGRES_PASSWORD=senha_segura_altere_esta
  ```

  * \[✅\] Serviço adicionado ao `docker-compose.yml`:

  ```yaml
  postgres:
    image: postgres:16-alpine
    env_file: .env
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network
  ```

* \[✅\] **1.A.3. Implantação:** 

  * \[✅\] Executado: `docker compose up -d postgres `

* \[✅\] **1.A.4. Verificação:** 

  * \[✅\] Serviço em execução: `docker compose ps `

  * \[✅\] Logs verificados: 
  ```bash
    docker compose logs postgres | grep "ready to accept"
  ```

### 1.B - Serviço Caddy \[✅\]

* \[✅\] **1.B.1. Pesquisa:** Imagem oficial Caddy e estrutura do Caddyfile

* \[✅\] **1.B.2. Configuração:** 
    * \[✅\] Consulte o [Tutorial de Configuração do Caddy](docs/setup_caddy.md) para um guia detalhado da sua configuração e funcionalidades neste projeto.
  * \[✅\] Criar arquivo `Caddyfile` básico:

  ```caddy
  {
    email ${CADDY_EMAIL}
  }

  galvani4987.duckdns.org {
    respond "Serviço Caddy Funcionando!"
  }
  ```

  * \[✅\] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  caddy:
    image: caddy:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config:/etc/caddy # Mounts the whole config directory
      - caddy_data:/data
      - caddy_config:/config
    env_file: # Ensure Caddy can access CADDY_EMAIL from .env
      - .env
    networks:
      - app-network
    restart: unless-stopped
  ```

  * \[✅\] Adicionar variável ao `.env`:

    ```
    CADDY_EMAIL=seu_email@provedor.com
    ```

* \[✅\] **1.B.3. Implantação:** 

  * \[✅\] Executar:
  `docker compose up -d caddy `

* \[✅\] **1.B.4. Verificação:** 
  * \[✅\] Verificar status:
  `docker compose ps `

  * \[✅\] Verificar logs:

    ```bash
    docker compose logs caddy
    ```

  * \[✅\] Testar acesso:

    ```bash
    curl https://galvani4987.duckdns.org
    ```

## Fase 2: Aplicações Web Principais \[✅\]

*Implantação do n8n e Homer*

### 2.A - Serviço n8n (Automação) \[✅\]

* \[✅\] **2.A.1. Pesquisa:** Configuração do n8n com PostgreSQL, variáveis de ambiente necessárias e integração com Caddy.

* \[✅\] **2.A.2. Configuração:** 
    * \[✅\] Consulte o [Tutorial de Instalação do n8n](docs/setup_n8n.md) para um guia detalhado de configuração e implantação.
  * \[✅\] Adicionar variáveis ao `.env`:

  ```env
  N8N_DB_TYPE=postgresdb
  N8N_DB_POSTGRESDB_HOST=postgres
  N8N_DB_POSTGRESDB_PORT=5432
  N8N_DB_POSTGRESDB_USER=${POSTGRES_USER}
  N8N_DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
  N8N_DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
  N8N_WEBHOOK_URL=https://n8n.galvani4987.duckdns.org/
  N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
  N8N_RUNNERS_ENABLED=true
  ```

  * \[✅\] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  n8n:
    image: n8nio/n8n:latest
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
      - N8N_WEBHOOK_URL=${N8N_WEBHOOK_URL}
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=${N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS}
      - N8N_RUNNERS_ENABLED=${N8N_RUNNERS_ENABLED}
      - N8N_HOST=n8n
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-America/Sao_Paulo}
      - TZ=${TZ:-America/Sao_Paulo}
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - app-network
    depends_on:
      postgres:
        condition: service_started
    ```

  * \[✅\] Configurar proxy no `Caddyfile` (será feito na Fase 3.B após Authelia):

  ```caddy
  n8n.galvani4987.duckdns.org {
    reverse_proxy n8n:5678
    # forward_auth http://authelia:9091 { # será adicionado após Authelia
    #   uri /authelia
    # }
  }
  ```

* \[✅\] **2.A.3. Implantação:**
  - Assegurar que o serviço PostgreSQL esteja em execução.
  - Executar `docker compose up -d n8n` para iniciar o container.
* \[✅\] **2.A.4. Verificação:**
  - Monitorar logs de inicialização com `docker compose logs n8n`.
  - Acessar a interface web em `https://n8n.galvani4987.duckdns.org`.
  - Realizar o setup inicial do usuário administrador.
  - Testar a criação e execução de um workflow simples para confirmar funcionalidade.

### 2.B - Serviço Homer (Dashboard Principal) \[✅\]

* \[✅\] **2.B.1. Pesquisa:** Imagem oficial Homer, estrutura de configuração e como servir arquivos estáticos via Caddy.

* \[✅\] **2.B.2. Configuração:**
    * \[✅\] Consulte o [Tutorial de Instalação do Homer](docs/setup_homer.md) para um guia detalhado de configuração e implantação.
  * \[✅\] Criar diretório `config/homer` e adicionar o arquivo `config.yml` (exemplo básico):

  ```yaml
  # config.yml para Homer
  title: "Dashboard do Servidor"
  subtitle: "Acesso aos serviços self-hosted"
  logo: "assets/logo.png" # Crie um logo ou use um placeholder

  links:
    - name: n8n
      icon: "fas fa-robot"
      url: https://n8n.galvani4987.duckdns.org
    # Adicione mais links aqui
  ```

  * \[ \] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  homer:
    image: b4bz/homer:latest
    container_name: homer
    user: "1000:1000" # UID:GID do host para permissões de ./config/homer
    volumes:
      - ./config/homer:/www/assets
    networks:
      - app-network
    restart: unless-stopped
    environment:
      - INIT_ASSETS=0 # Não reinicializar assets, pois config.yml é gerenciado
  ```

  * \[✅\] Configurar proxy no `Caddyfile` para o domínio raiz (será feito na Fase 3.B após Authelia):

  ```caddy
  galvani4987.duckdns.org {
    # forward_auth http://authelia:9091 { # será adicionado após Authelia
    #   uri /authelia
    # }
    reverse_proxy homer:8080
  }
  ```

* \[✅\] **2.B.3. Implantação:**
  - Adicionado ao `docker-compose.yml`. Use `docker compose up -d homer` para iniciar.
* \[✅\] **2.B.4. Verificação:**
  - Acessar `https://galvani4987.duckdns.org` (ou seu domínio raiz). Verificar logs com `docker compose logs homer`.
---

## Fase 3: Segurança e Serviços Especializados \[✅\]

*Autenticação com Authelia e gateway Waha*

### 3.A - Serviço Redis (Dependência do Authelia) \[✅\]

* \[✅\] **3.A.1. Pesquisa:** Imagem Redis oficial (`redis:alpine`) e como configurar volumes para persistência.

* \[✅\] **3.A.2. Configuração:**
    * \[✅\] Consulte o [Tutorial de Instalação do Redis](docs/setup_redis.md) para um guia detalhado de configuração e implantação.
  * \[✅\] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  redis:
    image: redis:alpine
    container_name: redis
    restart: unless-stopped
    command: redis-server --save 60 1 --loglevel warning --requirepass ${REDIS_PASSWORD}
    env_file:
      - .env
    volumes:
      - redis_data:/data
    networks:
      - app-network
  ```

* \[✅\] **3.A.3. Implantação:**
  - Adicionado ao `docker-compose.yml`. Use `docker compose up -d redis` para iniciar.
* \[✅\] **3.A.4. Verificação:**
  - Verificar logs com `docker compose logs redis`. Testar conexão (e.g., via Authelia quando este estiver online).

### 3.B - Serviço Authelia (Portal de Autenticação) \[✅\]

* \[✅\] **3.B.1. Pesquisa:** Documentação oficial do Authelia, configuração do `configuration.yml`, chaves para 2FA, e integração com Caddy via `forward_auth`.

* \[✅\] **3.B.2. Configuração:**
    * \[✅\] Consulte o [Tutorial de Instalação do Authelia](docs/setup_authelia.md) para um guia detalhado de configuração e implantação.
  * \[✅\] Criar diretório `config/authelia` com `configuration.yml` e `users.yml`.
  * \[✅\] Adicionar segredos ao `.env` (conforme `docs/setup_authelia.md`, incluindo `AUTHELIA_JWT_SECRET`, `AUTHELIA_SESSION_SECRET`, `AUTHELIA_STORAGE_ENCRYPTION_KEY`, etc.).

  * \[✅\] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    restart: unless-stopped
    env_file:
      - .env # For all AUTHELIA_ variables
    volumes:
      - ./config/authelia:/config
    networks:
      - app-network
    depends_on:
      redis:
        condition: service_started
      postgres: # For notifications/audit log
        condition: service_started
  ```

  * \[✅\] Configurar `forward_auth` no `Caddyfile` para os serviços protegidos (Homer, n8n, Waha, Cockpit) e o subdomínio do Authelia:

  ```caddy
  authelia.galvani4987.duckdns.org {
    reverse_proxy authelia:9091
  }

  galvani4987.duckdns.org { # Homer
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.galvani4987.duckdns.org/
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy homer:8080
  }

  n8n.galvani4987.duckdns.org {
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.galvani4987.duckdns.org/
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy n8n:5678 # Headers específicos do n8n já no Caddyfile
  }

  cockpit.galvani4987.duckdns.org {
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://authelia.galvani4987.duckdns.org/
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy host.docker.internal:9090 # Headers específicos do Cockpit já no Caddyfile
  }

  # waha.galvani4987.duckdns.org (será adicionado na próxima fase)
  ```

* \[✅\] **3.B.3. Implantação:**
  - Adicionado ao `docker-compose.yml`. Use `docker compose up -d authelia` para iniciar (após Redis e Postgres).
* \[✅\] **3.B.4. Verificação:**
  - Verificar logs com `docker compose logs authelia`. Testar login no portal Authelia e acesso a uma rota protegida.

### 3.C - Serviço Waha (WhatsApp Gateway) \[✅\]

* \[✅\] **3.C.1. Pesquisa:** Imagem oficial Waha (`devlikeapro/waha:latest`), variáveis de ambiente para configuração (ex: `WAHA_DEBUG`, `WAHA_WEBHOOK_URL`, `WHATSAPP_API_KEY`).

* \[✅\] **3.C.2. Configuração:**
    * \[✅\] Consulte o [Tutorial de Instalação do WAHA](docs/setup_waha.md) para um guia detalhado de configuração e implantação.
  * \[✅\] Adicionar variáveis ao `.env` (ex: `WAHA_DEBUG=false`, `WHATSAPP_HOOK_URL`, `WHATSAPP_API_KEY`, etc., conforme `docs/setup_waha.md`).

  * \[✅\] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  waha:
    image: devlikeapro/waha:latest
    container_name: waha
    restart: unless-stopped
    env_file:
      - .env
    # ports: # Comentado por padrão após configuração inicial
    #   - "127.0.0.1:3000:3000"
    volumes:
      - ./config/waha/sessions:/app/.sessions
      - ./config/waha/media:/app/.media
    networks:
      - app-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
  ```

  * \[✅\] Configurar proxy no `Caddyfile` com autenticação:

  ```caddy
  waha.galvani4987.duckdns.org {
    forward_auth http://authelia:9091 {
      uri /authelia
    }
    reverse_proxy waha:3000
  }
  ```

* \[✅\] **3.C.3. Implantação:**
  - Adicionado ao `docker-compose.yml`. Use `docker compose up -d waha` para iniciar. Configuração inicial (QR code) pode exigir expor a porta temporariamente.
* \[✅\] **3.C.4. Verificação:**
  - Verificar logs com `docker compose logs waha`. Testar endpoints da API após autenticação e configuração da sessão do WhatsApp.

---

## Fase 4: Gerenciamento do Servidor \[✅\]

*Instalação do Cockpit para administração*

* \[✅\] **4.1. Pesquisa:** Instalação do Cockpit no Ubuntu 24.04 e permissões de acesso. (Já coberto pelo `bootstrap.sh`)

* \[✅\] **4.2. Implantação:** - \[✅\] Instalação via `bootstrap.sh` (O script já inclui `apt-get install -y cockpit` e `systemctl enable --now cockpit.socket`).

* \[✅\] **4.3. Verificação:**
  - Acessar via proxy reverso em `https://cockpit.galvani4987.duckdns.org` (requer Authelia).
  - Realizar login no Authelia e, em seguida, com as credenciais do usuário do servidor host.
  - Verificar a interface do Cockpit e funcionalidades básicas (ex: visão geral do sistema, logs, terminal).
  - O acesso direto via `https://<IP_DO_SERVIDOR>:9090` também pode ser usado para verificação (se o firewall do host permitir), contornando o proxy e Authelia.

## Fase 5: Finalização e Backup \[▶️]

*Implementação de estratégia de backup*

* \[✅] **5.1. Pesquisa:** Estratégias de backup para Docker (volumes, bancos de dados), ferramentas (ex: `restic`, scripts tar/gzip) e opções de armazenamento remoto (ex: S3, rclone).

    **Estratégia Proposta:**

    A estratégia de backup para este projeto se concentrará em garantir a consistência dos dados para serviços stateful e a integridade dos arquivos de configuração críticos.

    1.  **Dados Stateful:**
        *   **PostgreSQL (`postgres_data` volume):** Backup lógico utilizando `pg_dumpall` (ou `pg_dump` por banco) executado via `docker exec`. Isso garante um backup consistente do banco de dados. A restauração será feita via `psql`.
        *   **Redis (`redis_data` volume):** Backup do arquivo RDB persistido pelo Redis. O Redis será configurado para salvar snapshots periodicamente. O volume contendo o arquivo RDB será arquivado.
        *   **n8n (`n8n_data` volume):** Backup completo do volume, que contém o banco de dados SQLite (padrão), arquivos de configuração e workflows.
        *   **Caddy (`caddy_data` e `caddy_config` volumes/mapeamentos):** Backup do volume `caddy_data` (contendo certificados ACME e outros dados operacionais) e do diretório de configuração `./config` (que inclui `Caddyfile` e é montado em `/etc/caddy`).
        *   **Authelia (`./config/authelia` mapeamento):** Backup completo do diretório de configuração, que inclui `configuration.yml`, `users.yml`, e o banco de dados SQLite (se usado para auditoria/notificações, embora a configuração atual use Postgres para isso).
        *   **Homer (`./config/homer` mapeamento):** Backup completo do diretório de configuração.
        *   **Waha (`./config/waha/sessions` e `./config/waha/media` mapeamentos):** Backup completo dos diretórios de sessões e mídias.

    2.  **Arquivos de Configuração do Projeto:**
        *   `.env`: Contém todos os segredos e é CRÍTICO para o backup.
        *   `docker-compose.yml`: Define toda a stack de serviços.
        *   Outros scripts ou arquivos de configuração relevantes no diretório do projeto.

    3.  **Método de Backup Primário (Scripts Locais):**
        *   Utilização de scripts shell (`backup.sh`, `restore.sh`) para orquestrar o processo.
        *   Os scripts irão parar os containers relevantes (para garantir consistência dos dados onde necessário), executar os dumps de banco de dados, e arquivar os volumes/diretórios de configuração usando `tar` com compressão (gzip).
        *   Os backups serão armazenados localmente em um diretório dedicado no host.

    4.  **Frequência e Retenção:**
        *   **Frequência Sugerida:** Diária (automatizada via cron).
        *   **Retenção Sugerida:** Manter os últimos 7-30 backups diários (configurável pelo usuário).

    5.  **Considerações Importantes:**
        *   **Downtime:** A estratégia de parar containers para backup de volumes garante maior consistência, mas implica em um curto período de indisponibilidade dos serviços. Alternativas (como snapshots LVM, se aplicável ao host) podem ser consideradas para cenários mais exigentes.
        *   **Segurança dos Backups:** Backups contêm dados sensíveis (incluindo o `.env`). Devem ser protegidos adequadamente, especialmente se enviados para locais remotos (a criptografia com `restic` ou GPG é recomendada).

* \[▶️] **5.2. Configuração:**
    *   \[ ] Criar script `scripts/backup.sh` para backup dos volumes do Docker e dados do PostgreSQL.
    *   \[ ] Adicionar script `scripts/restore.sh` para facilitar a recuperação.
    *   \[ ] Configurar cron job diário para o script de backup.

    **Esboço Detalhado para `scripts/backup.sh`:**

    1.  **Definições e Configurações Iniciais:**
        *   Variáveis: Diretório de backup, nome do arquivo de backup (com timestamp), logs do script.
        *   Verificações: Existência do diretório de backup, permissões.
    2.  **Manutenção (Opcional):**
        *   Ativar modo de manutenção (se aplicável).
    3.  **Parada de Serviços (Ordem Importante):**
        *   Parar serviços que dependem de outros primeiro (e.g., `waha`, `n8n`, `homer`, `authelia`, `caddy`).
        *   `docker compose stop <lista_de_servicos_sem_db>`
    4.  **Backup do PostgreSQL:**
        *   `docker exec <container_postgres> pg_dumpall -U ${POSTGRES_USER} > ${DIR_BACKUP}/postgres_dump_\$(date +%Y%m%d_%H%M%S).sql`
        *   (Considerar tratamento seguro de senha do PG).
    5.  **Backup do Redis:**
        *   Parar Redis: `docker compose stop redis`.
        *   Copiar/arquivar o arquivo RDB do volume do Redis (e.g., `tar -czf ${DIR_BACKUP}/redis_data_\$(date +%Y%m%d_%H%M%S).tar.gz /caminho/para/volume/redis_data`).
    6.  **Backup dos Volumes e Diretórios de Configuração Mapeados:**
        *   Para cada volume/diretório mapeado essencial (n8n_data, caddy_data, ./config/caddy, ./config/authelia, ./config/homer, ./config/waha):
            *   `tar -czf ${DIR_BACKUP}/<nome_servico>_data_\$(date +%Y%m%d_%H%M%S).tar.gz /caminho/para/volume_ou_diretorio_host`
    7.  **Backup de Arquivos Críticos do Projeto:**
        *   Copiar `.env`, `docker-compose.yml` para o diretório de backup.
    8.  **Reinício dos Serviços:**
        *   `docker compose start redis`
        *   `docker compose start <lista_de_serviços_parados_anteriormente>` (ou `docker compose up -d` para todos).
    9.  **Limpeza de Backups Antigos (Retenção):**
        *   Implementar lógica para remover backups mais antigos que X dias.
    10. **Log e Notificação (Opcional):**
        *   Registrar sucesso/falha. Enviar notificação.
    11. **Manutenção (Opcional):**
        *   Desativar modo de manutenção.

    **Esboço Detalhado para `scripts/restore.sh`:**

    1.  **Definições e Verificações:**
        *   Variável: Caminho para o arquivo de backup a ser restaurado.
        *   Verificar existência do arquivo de backup.
    2.  **Parada Completa da Stack:**
        *   `docker compose down` (ou `stop` para todos os serviços).
    3.  **Restauração dos Volumes e Diretórios de Configuração:**
        *   Para cada volume/diretório: extrair o `tar.gz` correspondente para o local correto (host ou volume Docker).
    4.  **Restauração dos Arquivos Críticos do Projeto:**
        *   Copiar `.env`, `docker-compose.yml` do backup para a raiz do projeto.
    5.  **Restauração do PostgreSQL:**
        *   Iniciar apenas o PostgreSQL: `docker compose up -d postgres`.
        *   Aguardar inicialização.
        *   `docker exec -i <container_postgres> psql -U ${POSTGRES_USER} < ${CAMINHO_BACKUP}/postgres_dump.sql`.
    6.  **Restauração do Redis:**
        *   (Opcional, se o RDB foi restaurado com o volume) Iniciar Redis: `docker compose up -d redis`.
    7.  **Início Completo da Stack:**
        *   `docker compose up -d`.
    8.  **Verificação Pós-Restauração:**
        *   Instruções para o usuário verificar a integridade dos dados e funcionalidade dos serviços.

    **Configuração do Cron Job para `backup.sh`:**
    *   Exemplo: `0 2 * * * /caminho/para/scripts/backup.sh >> /var/log/backup_script.log 2>&1` (Executar diariamente às 02:00).
    *   Instruções para adicionar via `crontab -e`.

* \[ \] **5.3. Verificação:** 
    *   \[ ] Teste de backup/restore (simular um desastre para garantir a recuperação).

    **Esboço Detalhado para Verificação:**

    1.  **Executar Backup Completo:**
        *   Rodar o script `scripts/backup.sh` para criar um backup completo em um ambiente de teste ou em um momento de baixa atividade.
    2.  **Simular Cenário de Perda de Dados/Desastre:**
        *   Parar todos os serviços (`docker compose down`).
        *   Remover/renomear volumes Docker importantes (e.g., `postgres_data`, `n8n_data`).
        *   Remover/renomear diretórios de configuração mapeados (e.g., `./config/authelia`, `.env`).
    3.  **Executar Restauração Completa:**
        *   Rodar o script `scripts/restore.sh`, apontando para o backup criado no passo 1.
    4.  **Verificação Pós-Restauração:**
        *   Confirmar que todos os serviços iniciam corretamente (`docker compose ps -a`).
        *   Verificar logs dos serviços para erros de inicialização ou corrupção.
        *   Acessar as UIs dos serviços (Homer, n8n, Authelia, Cockpit, Waha) e verificar se os dados e configurações foram restaurados:
            *   **PostgreSQL:** Checar dados em tabelas específicas (e.g., usuários n8n, configurações Authelia se armazenadas em DB).
            *   **n8n:** Verificar workflows, credenciais, execuções passadas.
            *   **Authelia:** Verificar se usuários e regras de acesso funcionam.
            *   **Caddy:** Verificar se os certificados SSL estão corretos e os sites carregam.
            *   **Homer/Waha/Redis:** Verificar suas configurações e dados específicos.
        *   Testar funcionalidades chave de cada serviço.
    5.  **Documentar Resultados:**
        *   Registrar o sucesso ou falhas do teste, tempo de restauração, e quaisquer problemas encontrados. Ajustar scripts/procedimentos conforme necessário.

## Progresso Atual

```mermaid
gantt
    title Progresso da Implantação
    dateFormat  YYYY-MM-DD
    section Fase 0
    Preparação do Ambiente       :done,    des1, 2024-06-10, 2d
    section Fase 1
    PostgreSQL                   :done,    des2, 2024-06-11, 3d
    Caddy                        :done,    des3, 2024-06-12, 4d
    section Fase 2
    n8n                          :active,  des4, 2024-06-13, 3d
    Homer                        :         des5, after des4, 3d
    section Fase 3
    Redis                        :         des6, after des5, 2d
    Authelia                     :         des7, after des6, 5d
    Waha                         :         des8, after des7, 3d
    section Fase 4
    Cockpit                      :active,  des9, after des8, 2d
    section Fase 5
    Backup                       :         des10, after des9, 3d

