# Roadmap de Implantação Detalhado

**Estado Atual:** Todas as fases de implantação de serviços (Fase 0, 1, 2, 4, X) estão concluídas, com todos os serviços (PostgreSQL, Caddy, n8n, Cockpit, Authentik) operacionais. A Fase 5 (Backup) está com a configuração dos scripts implementada; no entanto, os testes completos de restauração ainda estão pendentes, e esta fase é considerada em andamento.

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
    *Nota: A instância principal do PostgreSQL descrita aqui (para n8n, etc.) utiliza a imagem `postgres:16-alpine`. O Authentik utiliza uma instância PostgreSQL separada (`authentik-postgres`) com a imagem `postgres:15-alpine`.*
  * \[✅\] Variáveis adicionadas ao `.env`:

  ```env
  POSTGRES_DB=n8n
  POSTGRES_USER=n8n
  POSTGRES_PASSWORD=<CHANGE_THIS_TO_A_STRONG_PASSWORD>
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

## Fase 2: Automação (n8n) \[✅\]

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
  N8N_WEBHOOK_URL=https://n8n.{$DOMAIN_NAME}/
  N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
  N8N_RUNNERS_ENABLED=false
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

  * \[✅\] Configurar proxy no `Caddyfile`:

  ```caddy
  n8n.galvani4987.duckdns.org {
    reverse_proxy n8n:5678 {
        header_up Host {host}
        header_up X-Real-IP {remote} # {remote} is <ip>:<port>, {client_ip} is just <ip>
        header_up X-Forwarded-Proto {scheme}
    }
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

---

## Fase 4: Gerenciamento do Servidor \[✅\]

*Instalação do Cockpit para administração*

* \[✅\] **4.1. Pesquisa:** Instalação do Cockpit no Ubuntu 24.04 e permissões de acesso. (Já coberto pelo `bootstrap.sh`)

* \[✅\] **4.2. Implantação:** - \[✅\] Instalação via `bootstrap.sh` (O script já inclui `apt-get install -y cockpit` e `systemctl enable --now cockpit.socket`).

* \[✅\] **4.3. Verificação:**
  - Acessar via proxy reverso em `https://cockpit.galvani4987.duckdns.org`.
  - Realizar login com as credenciais do usuário do servidor host.
  - Verificar a interface do Cockpit e funcionalidades básicas (ex: visão geral do sistema, logs, terminal).
  - O acesso direto via `https://<IP_DO_SERVIDOR>:9090` também pode ser usado para verificação (se o firewall do host permitir), contornando o proxy.

## Fase X: Identity Management & SSO (Authentik) [✅]

*Implementação do Authentik como provedor de identidade central e SSO.*

*   \[✅] **X.1. Pesquisa:** Imagens Docker do Authentik (`ghcr.io/goauthentik/server`, `ghcr.io/goauthentik/proxy`), PostgreSQL e Redis como dependências, configuração de Caddy para Authentik e outposts.
*   \[✅] **X.2. Configuração:**
    *   \[✅] Adicionados serviços `authentik-postgres`, `authentik-redis`, `authentik-server`, `authentik-worker` ao `docker-compose.yml`.
    *   \[✅] Adicionados serviços de outpost `authentik_proxy_n8n`, `authentik_proxy_cockpit` ao `docker-compose.yml`.
    *   \[✅] Adicionadas todas as variáveis `AUTHENTIK_*` (core e outpost tokens) ao `.env.example` e ao `.env`.
    *   \[✅] Configurado Caddyfile para rotear `{$DOMAIN_NAME}` e `auth.{$DOMAIN_NAME}` para `authentik-server:9000`.
    *   \[✅] Configurado Caddyfile para rotear subdomínios de aplicações (n8n, cockpit) para seus respectivos outposts Authentik (ex: `authentik_proxy_n8n:9000`).
    *   \[✅] Criado `docs/setup_authentik.md` com guia detalhado de instalação, configuração do Google OAuth, e proteção de aplicações.
*   \[✅] **X.3. Implantação:**
    *   \[✅] Serviços Authentik e outposts iniciados via `docker compose up -d`.
    *   \[✅] Configuração inicial do Authentik UI realizada (admin user, Google OAuth provider, Applications, Providers, Outposts para n8n, Cockpit).
    *   \[✅] Tokens de outpost preenchidos no `.env` e outposts reiniciados.
*   \[✅] **X.4. Verificação:**
    *   \[✅] Acesso a `https://{$DOMAIN_NAME}` redireciona para o login do Authentik.
    *   \[✅] Login com `akadmin` e Google OAuth funcionais.
    *   \[✅] Acesso a `https://n8n.{$DOMAIN_NAME}`, `https://cockpit.{$DOMAIN_NAME}` são protegidos pelo Authentik.
    *   \[✅] Redirecionamento para aplicações após login bem-sucedido.
    *   \[✅] Logs do Authentik server, worker, e outposts verificados.

## Fase 5: Finalização e Backup [▶️]

*Implementação de estratégia de backup*

* \[✅] **5.1. Pesquisa:** Estratégias de backup para Docker (volumes, bancos de dados), ferramentas (ex: `restic`, scripts tar/gzip) e opções de armazenamento remoto (ex: S3, rclone).

    **Estratégia Proposta:**

    A estratégia de backup para este projeto se concentrará em garantir a consistência dos dados para serviços stateful e a integridade dos arquivos de configuração críticos.

    1.  **Dados Stateful:**
        *   **PostgreSQL (`postgres_data` volume):** Backup lógico utilizando `pg_dumpall` (ou `pg_dump` por banco) executado via `docker exec`. Isso garante um backup consistente do banco de dados. A restauração será feita via `psql`.
        *   **n8n (`n8n_data` volume):** Backup completo do volume, que contém o banco de dados SQLite (padrão), arquivos de configuração e workflows.
        *   **Caddy (`caddy_data` e `caddy_config` volumes/mapeamentos):** Backup do volume `caddy_data` (contendo certificados ACME e outros dados operacionais) e do diretório de configuração `./config` (que inclui `Caddyfile` e é montado em `/etc/caddy`).

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

* \[✅] **5.2. Configuração:**
    *   \[✅] Criar script `scripts/backup.sh` para backup dos volumes do Docker e dados do PostgreSQL.
    *   \[✅] Adicionar script `scripts/restore.sh` para facilitar a recuperação.
    *   \[✅] **Configurar cron job diário para o script de backup.**
        Adicione a seguinte linha ao crontab do usuário `ubuntu` (ou o usuário que gerencia a stack):
        ```cron
        0 2 * * * /home/ubuntu/docker-stack/scripts/backup.sh >> /home/ubuntu/docker-stack/logs/backup_cron.log 2>&1
        ```
        *   **Permissão de Execução:** Certifique-se de que o script de backup é executável:
            ```bash
            chmod +x /home/ubuntu/docker-stack/scripts/backup.sh
            ```
        *   **Edição da Crontab:** Abra o editor de crontab do usuário que deverá executar o backup (geralmente o mesmo usuário que gerencia a stack Docker, e.g., `ubuntu`):
            ```bash
            crontab -e
            ```
        *   **Adicionar Linha do Cron:** Adicione a seguinte linha para executar o backup diariamente às 02:00 da manhã. Ajuste o caminho e o horário conforme necessário:
            ```cron
            0 2 * * * /home/ubuntu/docker-stack/scripts/backup.sh >> /home/ubuntu/docker-stack/logs/backup_cron.log 2>&1
            ```
            *   **Explicação da Linha:**
                *   `0 2 * * *`: Executa à 02:00 todos os dias.
                *   `/home/ubuntu/docker-stack/scripts/backup.sh`: Caminho absoluto para o script de backup. **Verifique e ajuste este caminho para o seu ambiente.**
                *   `>> /home/ubuntu/docker-stack/logs/backup_cron.log 2>&1`: Redireciona a saída padrão (stdout) e erros padrão (stderr) para um arquivo de log específico para o cron job. O diretório `logs` deve existir na raiz do projeto (crie-o com `mkdir logs` se não existir). O script `backup.sh` já cria seu próprio log detalhado dentro do diretório de cada backup.
        *   **Verificação:** Após salvar a crontab, você pode listar as tarefas agendadas com `crontab -l` para confirmar. Monitore o arquivo de log do cron e os diretórios de backup para garantir que os backups estão sendo executados conforme o esperado.

    **Esboço Detalhado para `scripts/backup.sh`:**
    (Este esboço permanece o mesmo, não precisa ser repetido na substituição)


    **Esboço Detalhado para `scripts/restore.sh`:**
    (Este esboço permanece o mesmo, não precisa ser repetido na substituição)

* \[✅] **5.3. Verificação:**
    *   \[ ] Teste de backup/restore (simular um desastre para garantir a recuperação).

    **Esboço Detalhado para Verificação:**

    1.  **Executar Backup Completo:**
        *   Rodar o script `scripts/backup.sh` para criar um backup completo em um ambiente de teste ou em um momento de baixa atividade.
    2.  **Simular Cenário de Perda de Dados/Desastre:**
        *   Parar todos os serviços (`docker compose down`).
        *   Remover/renomear volumes Docker importantes (e.g., `postgres_data`, `n8n_data`).
        *   Remover/renomear diretórios de configuração mapeados (e.g., `./config/caddy`, `.env`).
    3.  **Executar Restauração Completa:**
        *   Rodar o script `scripts/restore.sh`, apontando para o backup criado no passo 1.
    4.  **Verificação Pós-Restauração:**
        *   Confirmar que todos os serviços iniciam corretamente (`docker compose ps -a`).
        *   Verificar logs dos serviços para erros de inicialização ou corrupção.
        *   Acessar as UIs dos serviços (n8n, Cockpit) e verificar se os dados e configurações foram restaurados:
            *   **PostgreSQL:** Checar dados em tabelas específicas (e.g., usuários n8n).
            *   **n8n:** Verificar workflows, credenciais, execuções passadas.
            *   **Caddy:** Verificar se os certificados SSL estão corretos e os sites carregam.
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
    n8n                          :done,  des4, 2024-06-13, 3d
    section Fase 4
    Cockpit                      :done,  des9, after des4, 2d
    section Fase X
    Authentik SSO                :done,    desX, after des9, 5d
    section Fase 5
    Backup                       :      des10, after desX, 3d

