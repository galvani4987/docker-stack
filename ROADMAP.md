# Roadmap de Implantação Detalhado

**Estado Atual:** Fase 1.B concluída, Fase 2.A em andamento  
**Última Atualização:** 11 de Junho de 2025  

**Domínio Base:** `galvani4987.duckdns.org`  
**Convenção de Subdomínio:** `aplicativo.galvani4987.duckdns.org`  

**Legenda:**  
- `[ ]` - Pendente  
- `[▶️]` - Em Andamento  
- `[✅]` - Concluído  

---

## Fase 0: Preparação do Ambiente ✅
*Configuração inicial do servidor e estrutura do projeto*

- [✅] **0.1. Pesquisa:** Melhores práticas para organização de projetos Docker  
- [✅] **0.2. Configuração:**  
    - [✅] Repositório clonado em `/home/ubuntu/docker-stack`  
    - [✅] Arquivo `.gitignore` criado com entrada `.env`  
    - [✅] Arquivo `.env` criado (template)  
    - [✅] `docker-compose.yml` com estrutura inicial  
    - [✅] Scripts criados:  
        - `bootstrap.sh` para configuração inicial  
        - `clean-server.sh` para reset completo  
    - [✅] `README.md` atualizado com instruções  
- [✅] **0.3. Verificação:**  
    - [✅] Estrutura de arquivos confirmada  

---

## Fase 1: A Fundação (Proxy Reverso e Banco de Dados) [▶️]
*Configuração do PostgreSQL e Caddy*

### 1.A - Serviço PostgreSQL [▶️]
- [✅] **1.A.1. Pesquisa:** Imagem oficial PostgreSQL (tag: `16-alpine`)  
- [✅] **1.A.2. Configuração:**  
    - [✅] Variáveis adicionadas ao `.env`:  
      ```env
      POSTGRES_DB=main_db
      POSTGRES_USER=admin
      POSTGRES_PASSWORD=senha_segura_altere_esta
      ```  
    - [✅] Serviço adicionado ao `docker-compose.yml`:  
      ```yaml
      postgres:
        image: postgres:16-alpine
        env_file: .env
        volumes:
          - postgres_data:/var/lib/postgresql/data
        networks:
          - app-network
      ```  
- [✅] **1.A.3. Implantação:**  
    - [✅] Executado: ```bash
      docker compose up -d postgres
      ```  
- [✅] **1.A.4. Verificação:**  
    - [✅] Serviço em execução: ```bash
      docker compose ps
      ```  
    - [✅] Logs verificados: ```bash
      docker compose logs postgres | grep "ready to accept"
      ```  

### 1.B - Serviço Caddy [▶️]
- [✅] **1.B.1. Pesquisa:** Imagem oficial Caddy e estrutura do Caddyfile  
- [✅] **1.B.2. Configuração:**  
    - [✅} Criar arquivo `Caddyfile` básico:  
      ```caddy
      {
        email ${CADDY_EMAIL}
      }
      
      galvani4987.duckdns.org {
        respond "Serviço Caddy Funcionando!"  
      }
      ```  
    - [✅] Adicionar serviço ao `docker-compose.yml`:  
      ```yaml
      caddy:
        image: caddy:alpine
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - ./Caddyfile:/etc/caddy/Caddyfile
          - caddy_data:/data
          - caddy_config:/config
        networks:
          - app-network
      ```  
    - [✅] Adicionar variável ao `.env`:  
      ```env
      CADDY_EMAIL=seu_email@provedor.com
      ```  
- [✅] **1.B.3. Implantação:**  
    - [✅] Executar: 
      ```bash
      docker compose up -d caddy
      ```  
- [✅] **1.B.4. Verificação:**  
    - [✅] Verificar status: 
      ```bash
      docker compose ps
      ```  
    - [✅] Verificar logs: 
      ```bash
      docker compose logs caddy
      ```  
    - [✅] Testar acesso: 
      ```bash
      curl https://galvani4987.duckdns.org
      ```  

---

## Fase 2: Aplicações Web Principais [ ]
*Implantação do n8n e Homer*

### 2.A - Serviço n8n (Automação) [ ]
- [✅] **2.A.1. Pesquisa:** Configuração do n8n com PostgreSQL  
- [ ] **2.A.2. Configuração:**  
    - [ ] Adicionar variáveis ao `.env`:  
      ```env
      N8N_DB_TYPE=postgresdb
      N8N_DB_POSTGRESDB_HOST=postgres
      N8N_DB_POSTGRESDB_PORT=5432
      N8N_DB_POSTGRESDB_USER=${POSTGRES_USER}
      N8N_DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      N8N_DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      ```  
    - [ ] Adicionar serviço ao `docker-compose.yml`  
    - [ ] Configurar proxy no `Caddyfile`  
- [ ] **2.A.3. Implantação:**  
- [ ] **2.A.4. Verificação:**  

### 2.B - Serviço Homer (Dashboard Principal) [ ]
- [ ] **2.B.1. Pesquisa:** Configuração do Homer  
- [ ] **2.B.2. Configuração:**  
    - [ ] Criar diretório `homer` com configurações  
    - [ ] Adicionar serviço ao `docker-compose.yml`  
    - [ ] Configurar proxy no `Caddyfile` com autenticação  
- [ ] **2.B.3. Implantação:**  
- [ ] **2.B.4. Verificação:**  

---

## Fase 3: Segurança e Serviços Especializados [ ]
*Autenticação com Authelia e gateway Waha*

### 3.A - Serviço Redis (Dependência do Authelia) [ ]
- [ ] **3.A.1. Pesquisa:** Imagem Redis oficial  
- [ ] **3.A.2. Configuração:**  
- [ ] **3.A.3. Implantação:**  
- [ ] **3.A.4. Verificação:**  

### 3.B - Serviço Authelia (Portal de Autenticação) [ ]
- [ ] **3.B.1. Pesquisa:** Integração Caddy + Authelia  
- [ ] **3.B.2. Configuração:**  
    - [ ] Criar diretório `authelia` com configurações  
    - [ ] Adicionar segredos ao `.env`  
    - [ ] Configurar `forward_auth` no Caddyfile  
- [ ] **3.B.3. Implantação:**  
- [ ] **3.B.4. Verificação:**  

### 3.C - Serviço Waha (WhatsApp Gateway) [ ]
- [ ] **3.C.1. Pesquisa:** Configuração do Waha  
- [ ] **3.C.2. Configuração:**  
- [ ] **3.C.3. Implantação:**  
- [ ] **3.C.4. Verificação:**  

---

## Fase 4: Gerenciamento do Servidor [ ]
*Instalação do Cockpit para administração*

- [ ] **4.1. Pesquisa:** Instalação do Cockpit no Ubuntu 24.04  
- [ ] **4.2. Implantação:**  
    - [ ] Instalação via `bootstrap.sh`  
- [ ] **4.3. Verificação:**  
    - [ ] Acesso em `https://<IP>:9090`  

---

## Fase 5: Finalização e Backup [ ]
*Implementação de estratégia de backup*

- [ ] **5.1. Pesquisa:** Estratégias de backup para Docker  
- [ ] **5.2. Configuração:**  
    - [ ] Criar script `backup.sh`  
    - [ ] Configurar cron job diário  
- [ ] **5.3. Verificação:**  
    - [ ] Teste de backup/restore  

---

## Progresso Atual
```mermaid
gantt
    title Progresso da Implantação
    dateFormat  YYYY-MM-DD
    section Fase 0
    Preparação do Ambiente       :done,    des1, 2025-06-10, 2d
    section Fase 1
    PostgreSQL                   :active,  des2, 2025-06-11, 3d
    Caddy                        :         des3, after des2, 4d
    section Fase 2
    n8n                          :         des4, after des3, 3d
    Homer                        :         des5, after des4, 3d
    section Fase 3
    Authelia                     :         des6, after des5, 5d
    Waha                         :         des7, after des6, 3d
    section Fase 4
    Cockpit                      :         des8, after des7, 2d
    section Fase 5
    Backup                       :         des9, after des8, 3d
