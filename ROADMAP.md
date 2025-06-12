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
  * \[ \] Cron job para `manter_ativo.sh` configurado (conforme instruções no README.md)

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
      - ./config/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
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

## Fase 2: Aplicações Web Principais \[▶️\]

*Implantação do n8n e Homer*

### 2.A - Serviço n8n (Automação) \[▶️\]

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
    networks:
      - app-network
    depends_on:
      - postgres
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

* \[ \] **2.A.3. Implantação:** 

* \[ \] **2.A.4. Verificação:** 

### 2.B - Serviço Homer (Dashboard Principal) \[ \]

* \[ \] **2.B.1. Pesquisa:** Imagem oficial Homer, estrutura de configuração e como servir arquivos estáticos via Caddy.

* \[ \] **2.B.2. Configuração:** 
    * \[ \] Consulte o [Tutorial de Instalação do Homer](docs/setup_homer.md) para um guia detalhado de configuração e implantação.
  * \[ \] Criar diretório `config/homer` e adicionar o arquivo `config.yml` (exemplo básico):

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
    volumes:
      - ./config/homer:/www/assets
    networks:
      - app-network
    restart: unless-stopped
  ```

  * \[ \] Configurar proxy no `Caddyfile` para o domínio raiz (será feito na Fase 3.B após Authelia):

  ```caddy
  galvani4987.duckdns.org {
    # forward_auth http://authelia:9091 { # será adicionado após Authelia
    #   uri /authelia
    # }
    reverse_proxy homer:8080
  }
  ```

* \[ \] **2.B.3. Implantação:** 

* \[ \] **2.B.4. Verificação:** 
---

## Fase 3: Segurança e Serviços Especializados \[ \]

*Autenticação com Authelia e gateway Waha*

### 3.A - Serviço Redis (Dependência do Authelia) \[ \]

* \[ \] **3.A.1. Pesquisa:** Imagem Redis oficial (`redis:alpine`) e como configurar volumes para persistência.

* \[ \] **3.A.2. Configuração:** 
    * \[ \] Consulte o [Tutorial de Instalação do Redis](docs/setup_redis.md) para um guia detalhado de configuração e implantação.
  * \[ \] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  redis:
    image: redis:alpine
    container_name: redis
    volumes:
      - redis_data:/data
    networks:
      - app-network
    restart: unless-stopped
  ```

* \[ \] **3.A.3. Implantação:** 

* \[ \] **3.A.4. Verificação:** 

### 3.B - Serviço Authelia (Portal de Autenticação) \[ \]

* \[ \] **3.B.1. Pesquisa:** Documentação oficial do Authelia, configuração do `configuration.yml`, chaves para 2FA, e integração com Caddy via `forward_auth`.

* \[ \] **3.B.2. Configuração:** 
    * \[ \] Consulte o [Tutorial de Instalação do Authelia](docs/setup_authelia.md) para um guia detalhado de configuração e implantação.
  * \[ \] Criar diretório `config/authelia` com `configuration.yml` e `users.yml`.

  * \[ \] Adicionar segredos ao `.env` (ex: `AUTHELIA_JWT_SECRET`, `AUTHELIA_SESSION_SECRET`, `AUTHELIA_DUO_API_SECRET`, `AUTHELIA_ADMIN_PASSWORD`).

  * \[ \] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    volumes:
      - ./config/authelia:/config
    environment:
      - AUTHELIA_JWT_SECRET=${AUTHELIA_JWT_SECRET}
      - AUTHELIA_SESSION_SECRET=${AUTHELIA_SESSION_SECRET}
      - AUTHELIA_DUO_API_SECRET=${AUTHELIA_DUO_API_SECRET} # se usar Duo
      - AUTHELIA_LOG_LEVEL=debug # ou info, warn, error
    networks:
      - app-network
    depends_on:
      - redis
    restart: unless-stopped
  ```

  * \[ \] Configurar `forward_auth` no `Caddyfile` para os serviços protegidos (Homer, n8n, Waha) e o subdomínio do Authelia:

  ```caddy
  authelia.galvani4987.duckdns.org {
    reverse_proxy authelia:9091
  }
  galvani4987.duckdns.org {
    forward_auth http://authelia:9091 {
      uri /authelia
    }
    reverse_proxy homer:8080
  }

  n8n.galvani4987.duckdns.org {
    forward_auth http://authelia:9091 {
      uri /authelia
    }
    reverse_proxy n8n:5678
  }
  # waha.galvani4987.duckdns.org (será adicionado na próxima fase)
  ```

* \[ \] **3.B.3. Implantação:** 

* \[ \] **3.B.4. Verificação:** 

### 3.C - Serviço Waha (WhatsApp Gateway) \[ \]

* \[ \] **3.C.1. Pesquisa:** Imagem oficial Waha (`devlikeapro/waha`), variáveis de ambiente para configuração (ex: `WAHA_DEBUG`, `WAHA_WEBHOOK_URL`).

* \[ \] **3.C.2. Configuração:**
    * \[ \] Consulte o [Tutorial de Instalação do WAHA](docs/setup_waha.md) para um guia detalhado de configuração e implantação.
  * \[ \] Adicionar variáveis ao `.env` (ex: `WAHA_DEBUG=false`, `WAHA_WEBHOOK_URL=<seu_webhook_url>`).

  * \[ \] Adicionar serviço ao `docker-compose.yml`:

  ```yaml
  waha:
    image: devlikeapro/waha:latest
    container_name: waha
    env_file:
      - .env
    environment:
      - WAHA_DEBUG=${WAHA_DEBUG}
      - WAHA_WEBHOOK_URL=${WAHA_WEBHOOK_URL}
    networks:
      - app-network
    restart: unless-stopped
  ```

  * \[ \] Configurar proxy no `Caddyfile` com autenticação:

  ```caddy
  waha.galvani4987.duckdns.org {
    forward_auth http://authelia:9091 {
      uri /authelia
    }
    reverse_proxy waha:3000
  }
  ```

* \[ \] **3.C.3. Implantação:** 

* \[ \] **3.C.4. Verificação:** 

---

## Fase 4: Gerenciamento do Servidor \[▶️\]

*Instalação do Cockpit para administração*

* \[✅\] **4.1. Pesquisa:** Instalação do Cockpit no Ubuntu 24.04 e permissões de acesso. (Já coberto pelo `bootstrap.sh`)

* \[✅\] **4.2. Implantação:** - \[✅\] Instalação via `bootstrap.sh` (O script já inclui `apt-get install -y cockpit` e `systemctl enable --now cockpit.socket`).

* \[ \] **4.3. Verificação:** - \[ \] Acesso em `https://<IP>:9090`

## Fase 5: Finalização e Backup \[ \]

*Implementação de estratégia de backup*

* \[ \] **5.1. Pesquisa:** Estratégias de backup para Docker (volumes, bancos de dados), ferramentas (ex: `restic`, scripts tar/gzip) e opções de armazenamento remoto (ex: S3, rclone).

* \[ \] **5.2. Configuração:** 

  * \[ \] Criar script `scripts/backup.sh` para backup dos volumes do Docker e dados do PostgreSQL.

  * \[ \] Adicionar script `scripts/restore.sh` para facilitar a recuperação.

  * \[ \] Configurar cron job diário para o script de backup.

* \[ \] **5.3. Verificação:** 

  * \[ \] Teste de backup/restore (simular um desastre para garantir a recuperação).

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

