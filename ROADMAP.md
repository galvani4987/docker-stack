# Roadmap de Implantação Detalhado

Este documento é o guia de execução passo a passo para a implantação da pilha de serviços. Cada fase e cada serviço seguem uma estrutura de **Pesquisa**, **Configuração**, **Implantação** e **Verificação**.

**Domínio Base:** `galvani4987.duckdns.org`
**Convenção de Subdomínio:** `aplicativo.galvani4987.duckdns.org`

**Legenda:**
- `[ ]` - Pendente
- `[▶️]` - Em Andamento
- `[✅]` - Concluído

---

## Fase 0: Preparação do Ambiente
*O objetivo desta fase é criar a estrutura de diretórios e arquivos base no servidor VPS.*

- [ ] **0.1. Pesquisa:** Entender as melhores práticas para organizar projetos Docker, incluindo o uso de `docker-compose.yml` para definição de serviços, `.env` para gerenciamento de segredos e `.gitignore` para segurança do repositório.

- [ ] **0.2. Configuração:**
    - [ ] Clonar o repositório `docker-stack` do GitHub para `/home/ubuntu/docker-stack` no servidor.
    - [ ] Dentro de `docker-stack`, criar o arquivo `.gitignore` com a entrada `.env`.
    - [ ] Criar o arquivo `.env` (inicialmente vazio).
    - [ ] Criar o arquivo `docker-compose.yml` com a estrutura inicial (versão e definição da rede customizada `app-network`).

- [ ] **0.3. Verificação:**
    - [ ] Executar `ls -la` dentro do diretório `docker-stack` e confirmar que todos os arquivos (`.env`, `.gitignore`, `docker-compose.yml`) e o diretório `.git` existem.

---

## Fase 1: A Fundação (Proxy Reverso e Banco de Dados)
*O objetivo é estabelecer os dois pilares da nossa infraestrutura: o Caddy para gerenciar o acesso externo e o PostgreSQL para armazenar dados.*

### 1.A - Serviço PostgreSQL
- [ ] **1.A.1. Pesquisa:**
    - [ ] Acessar o [Docker Hub](https://hub.docker.com/) e pesquisar por `postgres`.
    - [ ] Ler a documentação da imagem oficial. Anotar as tags de versão recomendadas (ex: `16-alpine`) e as variáveis de ambiente essenciais para a configuração inicial (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`).

- [ ] **1.A.2. Configuração:**
    - [ ] Adicionar as variáveis `POSTGRES_DB`, `POSTGRES_USER`, e `POSTGRES_PASSWORD` ao arquivo `.env` com valores seguros.
    - [ ] Adicionar a definição do serviço `postgres` ao `docker-compose.yml`, referenciando as variáveis do `.env` e configurando um volume nomeado para persistência de dados (`postgres_data`).

- [ ] **1.A.3. Implantação:**
    - [ ] Dentro do diretório `docker-stack` no servidor, executar `docker compose up -d postgres`.

- [ ] **1.A.4. Verificação:**
    - [ ] Executar `docker compose ps`. O serviço `postgres` deve estar com o status `running` (ou `up`).
    - [ ] Executar `docker compose logs postgres`. Verificar se não há erros e procurar pela mensagem "database system is ready to accept connections".

### 1.B - Serviço Caddy
- [ ] **1.B.1. Pesquisa:**
    - [ ] No Docker Hub, pesquisar por `caddy` e ler a documentação da imagem oficial.
    - [ ] Pesquisar por "Caddyfile basics" na documentação oficial do Caddy para entender a estrutura do `Caddyfile`.

- [ ] **1.B.2. Configuração:**
    - [ ] Criar um arquivo `Caddyfile` no diretório `docker-stack`.
    - [ ] Adicionar o bloco de opções globais ao `Caddyfile` com seu e-mail para o registro dos certificados SSL.
    - [ ] Adicionar a definição do serviço `caddy` ao `docker-compose.yml`, mapeando as portas `80` e `443`, o `Caddyfile` e os volumes para dados e configuração (`caddy_data`, `caddy_config`).

- [ ] **1.B.3. Implantação:**
    - [ ] Executar `docker compose up -d caddy`.

- [ ] **1.B.4. Verificação:**
    - [ ] Executar `docker compose ps`. O serviço `caddy` deve estar com o status `running` (ou `up`).
    - [ ] Executar `docker compose logs caddy`. Verificar se não há erros de inicialização.
    - [ ] **Verificação Externa:** Acessar `http://IP_DO_SERVIDOR` no navegador. Você deve ver uma página em branco ou uma mensagem de erro do Caddy, confirmando que ele está respondendo na porta 80.

---

## Fase 2: Aplicações Web Principais
*O objetivo é implantar o n8n e o Homer, conectando-os à nossa infraestrutura e expondo-os de forma segura na internet através de subdomínios.*

### 2.A - Serviço n8n (Automação)
- [ ] **2.A.1. Pesquisa:**
    - [ ] Pesquisar por "n8n docker install with postgres" na documentação oficial do n8n.
    - [ ] Identificar todas as variáveis de ambiente necessárias para conectar o n8n ao nosso contêiner `postgres`.

- [ ] **2.A.2. Configuração:**
    - [ ] Adicionar as variáveis de ambiente do n8n (ex: `DB_TYPE`, `DB_POSTGRESDB_HOST`, etc.) ao arquivo `.env`.
    - [ ] Adicionar a definição do serviço `n8n` ao `docker-compose.yml`, referenciando as variáveis do `.env` e configurando um volume para seus dados.
    - [ ] Editar o `Caddyfile` para adicionar um bloco de configuração para o subdomínio `n8n.galvani4987.duckdns.org`, instruindo o Caddy a fazer o proxy reverso para o serviço `n8n:5678`.

- [ ] **2.A.3. Implantação:**
    - [ ] Executar `docker compose up -d`. O Docker criará o contêiner do n8n e recarregará o Caddy com a nova configuração.

- [ ] **2.A.4. Verificação:**
    - [ ] `docker compose ps`: Verificar se o serviço `n8n` está `running`.
    - [ ] `docker compose logs n8n`: Verificar se o n8n iniciou sem erros e se mensagens de conexão com o banco de dados aparecem.
    - [ ] `docker compose logs caddy`: Verificar se o Caddy obteve um certificado SSL para `n8n.galvani4987.duckdns.org`.
    - [ ] **Verificação Externa:** Acessar **`https://n8n.galvani4987.duckdns.org`** no navegador. A página de configuração inicial do n8n deve carregar com um cadeado de HTTPS válido.

### 2.B - Serviço Homer (Dashboard Principal)
- [ ] **2.B.1. Pesquisa:**
    - [ ] Pesquisar por "Homer dashboard docker" no Docker Hub ou no GitHub do projeto (`bastienwirtz/homer`).
    - [ ] Encontrar o nome da imagem e entender como sua configuração funciona (mapeamento do diretório `/www/assets`).

- [ ] **2.B.2. Configuração:**
    - [ ] Criar um subdiretório `homer` dentro de `docker-stack` para guardar os arquivos de configuração do Homer.
    - [ ] Adicionar o serviço `homer` ao `docker-compose.yml`, mapeando o diretório `./homer:/www/assets`.
    - [ ] **Importante:** Adicionar um novo bloco no `Caddyfile` para o domínio raiz **`galvani4987.duckdns.org`**, que fará proxy para o serviço `homer:8080` e será protegido pelo Authelia.

- [ ] **2.B.3. Implantação:**
    - [ ] Executar `docker compose up -d`.

- [ ] **2.B.4. Verificação:**
    - [ ] `docker compose ps`: O serviço `homer` deve estar `running`.
    - [ ] `docker compose logs homer`: Verificar se não há erros.
    - [ ] **Verificação Externa:** Acessar **`https://galvani4987.duckdns.org`**. O acesso deve ser bloqueado e redirecionado para o portal de login do Authelia (após a Fase 3 ser implementada). Após o login, o dashboard do Homer deve carregar no domínio principal.
---

## Fase 3: Segurança e Serviços Especializados
*O objetivo é adicionar um portal de autenticação robusto com Authelia e implantar o gateway Waha.*

### 3.A - Serviço Redis (Dependência do Authelia)
*Redis é um banco de dados em memória ultrarrápido que o Authelia usará para armazenar dados de sessão.*

- [ ] **3.A.1. Pesquisa:**
    - [ ] Acessar o Docker Hub e pesquisar pela imagem oficial do `redis`.
    - [ ] Anotar a tag recomendada para produção (ex: `redis:7-alpine`).

- [ ] **3.A.2. Configuração:**
    - [ ] Adicionar a definição do serviço `redis` ao `docker-compose.yml`.
    - [ ] Configurar um volume nomeado (`redis_data`) para persistência de dados.

- [ ] **3.A.3. Implantação:**
    - [ ] Executar `docker compose up -d redis`.

- [ ] **3.A.4. Verificação:**
    - [ ] `docker compose ps`: Verificar se o serviço `redis` está `running`.
    - [ ] `docker compose logs redis`: Procurar pela mensagem "Ready to accept connections".

### 3.B - Serviço Authelia (Portal de Autenticação e 2FA)
- [ ] **3.B.1. Pesquisa:**
    - [ ] Acessar a documentação oficial do Authelia em `authelia.com`.
    - [ ] Focar nas seções de "Getting Started", "Configuration" e, crucialmente, na de "Integrations > Proxies > Caddy".
    - [ ] Entender a estrutura do arquivo `configuration.yml` do Authelia e como configurar o armazenamento de usuários (começaremos com um arquivo local) e a conexão com o Redis.

- [ ] **3.B.2. Configuração:**
    - [ ] Criar um diretório `./authelia` para os arquivos de configuração.
    - [ ] Criar o `authelia/configuration.yml` e o `authelia/users_database.yml` com base na documentação.
    - [ ] Adicionar as senhas e segredos do Authelia (JWT secret, senhas de notificação, etc.) ao arquivo `.env`.
    - [ ] Adicionar o serviço `authelia` ao `docker-compose.yml`, mapeando os arquivos de configuração e conectando-o às redes `app-network` e ao serviço `redis`.
    - [ ] No `Caddyfile`, adicionar o bloco para o portal do Authelia: `authelia.galvani4987.duckdns.org`.
    - [ ] No `Caddyfile`, modificar os blocos dos serviços que queremos proteger (ex: Homer, n8n) para incluir a diretiva `forward_auth` apontando para o Authelia.

- [ ] **3.B.3. Implantação:**
    - [ ] Executar `docker compose up -d`.

- [ ] **3.B.4. Verificação:**
    - [ ] `docker compose ps`: Verificar se `authelia` está `running`.
    - [ ] `docker compose logs authelia`: Verificar se ele iniciou com sucesso e se conectou ao Redis e ao banco de dados de usuários.
    - [ ] **Verificação Externa 1 (Portal):** Acessar **`https://authelia.galvani4987.duckdns.org`**. A página de login do Authelia deve carregar.
    - [ ] **Verificação Externa 2 (Serviço Protegido):** Tentar acessar um serviço protegido (ex: **`https://home.galvani4987.duckdns.org`**). Você deve ser redirecionado para a página de login do Authelia. Após o login, você deve ser redirecionado de volta para o Homer.

### 3.C - Serviço Waha (WhatsApp Gateway)
- [ ] **3.C.1. Pesquisa:**
    - [ ] Pesquisar por "waha whatsapp http api docker" para encontrar a documentação e a imagem Docker oficial.
    - [ ] Identificar variáveis de ambiente, portas e volumes necessários para gerenciamento de sessão.

- [ ] **3.C.2. Configuração:**
    - [ ] Adicionar o serviço `waha` ao `docker-compose.yml`.
    - [ ] Se necessário, adicionar um bloco ao `Caddyfile` para `waha.galvani4987.duckdns.org` e protegê-lo com `forward_auth` do Authelia.

- [ ] **3.C.3. Implantação:**
    - [ ] Executar `docker compose up -d`.

- [ ] **3.C.4. Verificação:**
    - [ ] `docker compose ps`: Verificar se o `waha` está `running`.
    - [ ] `docker compose logs waha`: Procurar por mensagens de sucesso na inicialização.
    - [ ] Testar a API ou acessar o subdomínio, conforme a documentação encontrada.
---

## Fase 4: Gerenciamento do Servidor
*O objetivo é instalar uma ferramenta para gerenciar o sistema operacional do servidor host.*

- [ ] **4.1. Pesquisa:**
    - [ ] Pesquisar por "install cockpit on ubuntu 24.04" para confirmar o procedimento e o nome do pacote.

- [ ] **4.2. Implantação:**
    - [ ] Executar `sudo apt update && sudo apt install cockpit -y`.
    - [ ] Executar `sudo systemctl enable --now cockpit.socket` para garantir que o serviço inicie com o servidor.

- [ ] **4.3. Verificação:**
    - [ ] Executar `systemctl status cockpit.socket`. O serviço deve estar `active` e `listening`.
    - [ ] **Verificação Externa:** Acessar **`https://IP_DO_SERVIDOR:9090`** no navegador. O navegador mostrará um aviso de segurança (pois o certificado é autoassinado), o que é normal. Prossiga para ver a tela de login do Cockpit.

---

## Fase 5: Finalização e Backup
*O objetivo é garantir a longevidade e segurança dos nossos dados.*

- [ ] **5.1. Pesquisa:**
    - [ ] Pesquisar por "docker backup strategy" e "backup docker named volumes".
    - [ ] Avaliar ferramentas como `restic`, `duplicity` ou scripts `bash` com `tar` para fazer backup dos diretórios de volumes do Docker (localizados em `/var/lib/docker/volumes`).

- [ ] **5.2. Configuração e Implantação:**
    - [ ] Escolher uma estratégia de backup.
    - [ ] Se for um script, criá-lo em `/home/ubuntu/scripts/backup.sh`.
    - [ ] Configurar um `cron job` para executar o script de backup regularmente (ex: toda madrugada). `crontab -e`.

- [ ] **5.3. Verificação:**
    - [ ] Executar o script de backup manualmente uma vez.
    - [ ] Verificar se o arquivo de backup foi criado corretamente e se contém dados.
    - [ ] Opcional, mas recomendado: Testar a restauração do backup em um diretório temporário para garantir sua integridade.
