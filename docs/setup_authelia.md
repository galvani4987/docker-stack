# Tutorial: Configurando o Authelia

Este tutorial detalhado guia você pela configuração e implantação do Authelia, o portal de autenticação e autorização para o projeto Docker Stack VPS. Authelia fornecerá login único (SSO) e autenticação de dois fatores (2FA).

**Atenção:** A configuração do Authelia é sensível e crucial para a segurança. Siga os passos com atenção.

## Pré-requisitos

1.  **Serviços Essenciais Rodando:**
    *   `caddy`: Configurado e rodando (Fase 1.B).
    *   `postgres`: Configurado e rodando (Fase 1.A). Authelia usará este banco de dados para seu armazenamento persistente.
    *   `redis`: Configurado e rodando com senha (Fase 3.A). Authelia usará Redis para gerenciamento de sessões.
2.  **Diretório de Configuração:** Crie o diretório no host para a configuração do Authelia:
    ```bash
    mkdir -p config/authelia
    ```
3.  **UID/GID do Usuário:** Identifique o UID e GID do usuário que irá gerenciar os arquivos de configuração do Authelia no host (geralmente `ubuntu`, UID/GID `1000`). Execute `id ubuntu` (ou `id $USER`).
4.  **DNS Configurado:** Certifique-se de que o subdomínio para Authelia (ex: `authelia.galvani4987.duckdns.org`) e os domínios dos serviços que ele protegerá (ex: `galvani4987.duckdns.org`, `n8n.galvani4987.duckdns.org`) estejam apontando para o IP do seu servidor.

## 1. Variáveis de Ambiente para Authelia

Adicione as seguintes variáveis ao seu arquivo `.env` na raiz do projeto. **Gere valores aleatórios e seguros para todos os segredos.**

```env
# --- Configurações do Authelia ---

# Segredos Fortes (gere strings aleatórias longas e seguras)
# Exemplo para gerar no terminal: openssl rand -hex 32
AUTHELIA_JWT_SECRET=seu_jwt_secret_super_seguro_aqui # Usado para assinar tokens JWT (ex: reset de senha)
AUTHELIA_SESSION_SECRET=seu_session_secret_super_seguro_aqui # Usado para criptografar a chave da sessão no Redis
AUTHELIA_STORAGE_ENCRYPTION_KEY=sua_storage_encryption_key_segura_aqui # Usado para criptografar dados no banco de dados do Authelia

# Configuração do Notificador (Filesystem para início, SMTP para produção é recomendado)
AUTHELIA_NOTIFIER_FILESYSTEM_FILENAME=/config/notifications.txt

# Configuração do Armazenamento (Storage) com PostgreSQL (usando o DB existente)
AUTHELIA_STORAGE_POSTGRES_HOST=postgres
AUTHELIA_STORAGE_POSTGRES_PORT=5432
AUTHELIA_STORAGE_POSTGRES_DATABASE=${POSTGRES_DB} # Reutiliza o DB principal
AUTHELIA_STORAGE_POSTGRES_USERNAME=${POSTGRES_USER} # Reutiliza o usuário admin do DB
AUTHELIA_STORAGE_POSTGRES_PASSWORD=${POSTGRES_PASSWORD} # Reutiliza a senha do admin do DB
AUTHELIA_STORAGE_POSTGRES_SCHEMA=authelia # Schema dedicado para Authelia dentro do DB principal
AUTHELIA_STORAGE_POSTGRES_SSL_MODE=disable # 'disable' para conexões internas na rede Docker sem SSL

# Configuração da Sessão com Redis
AUTHELIA_SESSION_REDIS_HOST=redis
AUTHELIA_SESSION_REDIS_PORT=6379
AUTHELIA_SESSION_REDIS_PASSWORD=${REDIS_PASSWORD} # Reutiliza a senha do Redis definida anteriormente
# AUTHELIA_SESSION_REDIS_USERNAME= # Geralmente não necessário para Redis com requirepass simples

# Domínio e URL base do Authelia
AUTHELIA_SERVER_DEFAULT_REDIRECT_URL=https://galvani4987.duckdns.org # Para onde redirecionar se Authelia for acessado diretamente

# Nível de Log (debug para setup inicial, info para produção)
AUTHELIA_LOG_LEVEL=debug
```

**Importante sobre Segredos:**
*   Use comandos como `openssl rand -hex 32` ou um gerenciador de senhas para gerar segredos fortes e únicos para `AUTHELIA_JWT_SECRET`, `AUTHELIA_SESSION_SECRET`, e `AUTHELIA_STORAGE_ENCRYPTION_KEY`.
*   Não use os exemplos `...aqui` no seu ambiente real.

## 2. Arquivo de Configuração Principal (`configuration.yml`)

Crie o arquivo `config/authelia/configuration.yml`. Este arquivo define a maior parte do comportamento do Authelia. As variáveis de ambiente definidas acima irão sobrescrever ou complementar estas configurações.

```yaml
# config/authelia/configuration.yml

# URL padrão para redirecionamento se Authelia for acessado diretamente
# Pode ser sobrescrito por AUTHELIA_SERVER_DEFAULT_REDIRECT_URL
default_redirection_url: https://galvani4987.duckdns.org/

# Configurações do servidor Authelia
server:
  host: 0.0.0.0
  port: 9091
  # trusted_proxies: # Adicione IPs/ranges da sua rede Docker se necessário, ex: ['172.16.0.0/12']
  #   - '10.0.0.0/8'
  #   - '172.16.0.0/12'
  #   - '192.168.0.0/16'

# Nível de Log - pode ser sobrescrito por AUTHELIA_LOG_LEVEL
log:
  level: info

# Segredo JWT global (usado se um segredo específico não for definido em outro lugar)
jwt_secret: "" # Será preenchido por AUTHELIA_JWT_SECRET

# Configuração da sessão
session:
  # Segredo para criptografar dados da sessão no Redis
  secret: "" # Será preenchido por AUTHELIA_SESSION_SECRET

  # Configuração do cookie de sessão principal
  # Estes são valores padrão, a seção 'cookies' abaixo é mais específica e recomendada.
  name: authelia_session
  expiration: 1h      # 1 hora
  inactivity: 5m      # 5 minutos
  remember_me: 1M     # 1 Mês (se "lembrar-me" for marcado)
  same_site: lax

  # Configuração específica do(s) domínio(s) do cookie
  # Esta seção é OBRIGATÓRIA e não pode ser totalmente definida por env vars.
  cookies:
    - domain: "galvani4987.duckdns.org" # Domínio principal que Authelia protegerá
      authelia_url: "https://authelia.galvani4987.duckdns.org" # URL do portal Authelia
      default_redirection_url: "https://galvani4987.duckdns.org" # Para onde ir após login
      # Outras opções como name, same_site, expiration, inactivity, remember_me podem ser herdadas ou especificadas aqui.

  # Configuração do Redis para armazenamento de sessão
  redis:
    host: "redis" # Nome do serviço Redis no Docker Compose
    port: 6379
    password: ""    # Será preenchido por AUTHELIA_SESSION_REDIS_PASSWORD
    # username: ""    # Geralmente não necessário para Redis com autenticação por senha simples
    database_index: 0 # Banco de dados Redis a ser usado (0 é o padrão)
    # maximum_active_connections: 8
    # minimum_idle_connections: 0

# Provedor de autenticação (primeiro fator)
authentication_backend:
  file:
    path: /config/users.yml # Caminho para o arquivo de banco de dados de usuários dentro do container
    # Configurações de hashing de senha (Argon2 é o padrão e recomendado)
    password:
      algorithm: argon2id
      iterations: 3
      memory: 65536       # Em KiB
      parallelism: 4
      key_length: 32
      salt_length: 16
    # watch: true # Opcional: recarrega users.yml em mudanças (pode não ser ideal em Docker)

# Armazenamento persistente para dados do Authelia (ex: segredos TOTP, registros de regulação)
storage:
  # Chave para criptografar dados no banco de dados
  encryption_key: "" # Será preenchido por AUTHELIA_STORAGE_ENCRYPTION_KEY

  # Configuração do PostgreSQL
  postgres:
    host: "postgres" # Nome do serviço PostgreSQL no Docker Compose
    port: 5432
    database: ""     # Será preenchido por AUTHELIA_STORAGE_POSTGRES_DATABASE
    username: ""     # Será preenchido por AUTHELIA_STORAGE_POSTGRES_USERNAME
    password: ""     # Será preenchido por AUTHELIA_STORAGE_POSTGRES_PASSWORD
    schema: "authelia" # Schema dedicado dentro do banco de dados principal
    sslmode: "disable" # Para conexões internas na rede Docker sem SSL

# Notificador (para reset de senha, registro de 2FA, etc.)
notifier:
  # Usando o sistema de arquivos para simplificar o setup inicial
  # Para produção, configure o SMTP: https://www.authelia.com/configuration/notifications/smtp/
  filesystem:
    filename: /config/notifications.txt # Caminho dentro do container

# Configuração de Autenticação de Dois Fatores (TOTP é o padrão)
totp:
  issuer: "Authelia - MeuServidor" # Nome do emissor que aparece no app autenticador

# Política de Acesso Padrão (inicialmente permissiva para o domínio configurado)
access_control:
  default_policy: deny # 'deny' é mais seguro por padrão
  rules:
    - domain: "*.galvani4987.duckdns.org" # Aplica a todos os subdomínios
      policy: one_factor # Requer um fator de autenticação (login/senha)
      # Para testes iniciais, 'bypass' pode ser usado temporariamente em vez de 'one_factor'.
      # Após configurar usuários e testar, mude para 'one_factor' ou 'two_factor'.
```

**Notas sobre `configuration.yml`:**
*   **Segredos Vazios:** Os campos de segredo (`jwt_secret`, `session.secret`, `storage.encryption_key`, `session.redis.password`, `storage.postgres.password`) são deixados vazios ou com aspas vazias (`""`) no YAML. Eles **serão preenchidos pelas variáveis de ambiente** correspondentes (`AUTHELIA_...`) que você definiu no `.env`.
*   **`server.trusted_proxies`:** Se você encontrar problemas com Authelia não reconhecendo o IP original do usuário (especialmente se Caddy e Authelia estiverem em redes Docker diferentes ou com configurações de rede complexas), você pode precisar adicionar o IP da rede Docker ou do Caddy a esta lista. Para a configuração deste projeto (mesma `app-network`), geralmente não é necessário.
*   **`storage.postgres.schema`:** Usar um schema dedicado (`authelia`) dentro do banco de dados PostgreSQL principal (`main_db`) é uma boa maneira de isolar os dados do Authelia sem precisar criar um banco de dados PostgreSQL inteiramente novo. Authelia irá criar este schema se ele não existir.
*   **`access_control`:** A regra inicial é definida para `one_factor` para `*.galvani4987.duckdns.org`. Isso significa que após o login bem-sucedido, o acesso é concedido. Você pode tornar isso mais rigoroso (`two_factor`) ou mais granular por serviço posteriormente.

## 3. Arquivo de Banco de Dados de Usuários (`users.yml`)

Crie o arquivo `config/authelia/users.yml`. Este arquivo define os usuários que podem se autenticar.

```yaml
# config/authelia/users.yml
# yaml-language-server: $schema=https://www.authelia.com/schemas/latest/json-schema/user-database.json

users:
  seu_usuario_admin: # Substitua pelo nome de usuário desejado
    disabled: false
    displayname: "Administrador"
    # Gere a senha usando o comando:
    # docker run --rm -it authelia/authelia:latest authelia crypto hash generate argon2
    # Substitua o hash abaixo pelo gerado. A senha de exemplo é 'minhasenhaforte'.
    password: "$argon2id$v=19$m=65536,t=3,p=4$longa_string_aleatoria_de_salt$hash_da_senha_resultante_aqui"
    email: "seu_email@exemplo.com"
    groups:
      - admins
      # - dev # Exemplo de outro grupo

  # Adicione mais usuários conforme necessário
  # outro_usuario:
  #   disabled: false
  #   displayname: "Usuário Comum"
  #   password: "gere_outro_hash_para_este_usuario"
  #   email: "outro@exemplo.com"
  #   groups:
  #     - users
```

**Gerando Hashes de Senha:**
*   **NÃO USE SENHAS EM TEXTO PLANO AQUI.**
*   Para gerar o hash da senha para o campo `password`, use o container Docker do Authelia:
    ```bash
    docker run --rm -it authelia/authelia:latest authelia crypto hash generate argon2
    ```
*   Quando solicitado, digite e confirme a senha desejada. O comando irá cuspir um hash (ex: `$argon2id$v=19$...`). Copie este hash completo e cole no campo `password` para cada usuário.
*   **Exemplo:** Se você quiser que a senha seja `minhasenhaforte`, execute o comando acima, digite `minhasenhaforte` duas vezes, e use o hash resultante.

## 4. Configuração no `docker-compose.yml`

Adicione o serviço `authelia` ao seu arquivo `docker-compose.yml`:

```yaml
services:
  # ... outros serviços ...

  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    volumes:
      - ./config/authelia:/config # Mapeia o diretório de configuração do host
    networks:
      - app-network
    expose: # Authelia não precisa ser exposto publicamente, apenas para Caddy
      - 9091
    environment:
      # Segredos e configurações principais do Authelia (do arquivo .env)
      - AUTHELIA_JWT_SECRET=${AUTHELIA_JWT_SECRET}
      - AUTHELIA_SESSION_SECRET=${AUTHELIA_SESSION_SECRET}
      - AUTHELIA_STORAGE_ENCRYPTION_KEY=${AUTHELIA_STORAGE_ENCRYPTION_KEY}

      - AUTHELIA_NOTIFIER_FILESYSTEM_FILENAME=${AUTHELIA_NOTIFIER_FILESYSTEM_FILENAME}

      - AUTHELIA_STORAGE_POSTGRES_HOST=${AUTHELIA_STORAGE_POSTGRES_HOST}
      - AUTHELIA_STORAGE_POSTGRES_PORT=${AUTHELIA_STORAGE_POSTGRES_PORT}
      - AUTHELIA_STORAGE_POSTGRES_DATABASE=${AUTHELIA_STORAGE_POSTGRES_DATABASE}
      - AUTHELIA_STORAGE_POSTGRES_USERNAME=${AUTHELIA_STORAGE_POSTGRES_USERNAME}
      - AUTHELIA_STORAGE_POSTGRES_PASSWORD=${AUTHELIA_STORAGE_POSTGRES_PASSWORD}
      - AUTHELIA_STORAGE_POSTGRES_SCHEMA=${AUTHELIA_STORAGE_POSTGRES_SCHEMA}
      - AUTHELIA_STORAGE_POSTGRES_SSL_MODE=${AUTHELIA_STORAGE_POSTGRES_SSL_MODE}

      - AUTHELIA_SESSION_REDIS_HOST=${AUTHELIA_SESSION_REDIS_HOST}
      - AUTHELIA_SESSION_REDIS_PORT=${AUTHELIA_SESSION_REDIS_PORT}
      - AUTHELIA_SESSION_REDIS_PASSWORD=${AUTHELIA_SESSION_REDIS_PASSWORD}
      # - AUTHELIA_SESSION_REDIS_USERNAME=${AUTHELIA_SESSION_REDIS_USERNAME}

      - AUTHELIA_SERVER_DEFAULT_REDIRECT_URL=${AUTHELIA_SERVER_DEFAULT_REDIRECT_URL}
      # A configuração session.cookies é feita no configuration.yml

      - AUTHELIA_LOG_LEVEL=${AUTHELIA_LOG_LEVEL}

      # Define o UID/GID para o container rodar. Deve corresponder ao proprietário de ./config/authelia
    user: "1000:1000" # Substitua pelo UID:GID correto
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_started # Ou service_healthy se postgres tiver healthcheck
      redis:
        condition: service_started # Ou service_healthy se redis tiver healthcheck
```

**Pontos Importantes:**
*   **`volumes:`** Mapeia `./config/authelia` para `/config` no container.
*   **`expose: - 9091`**: Expõe a porta 9091 apenas para outros containers na mesma rede Docker (como o Caddy), não para o host ou publicamente.
*   **`environment:`**: Mapeia as variáveis do `.env` para as variáveis de ambiente que Authelia espera.
*   **`user: "1000:1000"`**: **CRUCIAL.** Ajuste para o UID:GID do proprietário de `./config/authelia`.
*   **`depends_on:`**: Garante que PostgreSQL e Redis iniciem antes do Authelia.

## 5. Configuração do Caddy

Atualize seu `config/Caddyfile` para adicionar o portal Authelia e proteger seus outros serviços.

```caddy
{
    email ${CADDY_EMAIL} # Obtido do .env
    # default_sni seu_dominio_principal.com # Se necessário
}

# --- Portal Authelia ---
authelia.galvani4987.duckdns.org {
    reverse_proxy authelia:9091
}

# --- Homer (Dashboard Principal) - Protegido pelo Authelia ---
galvani4987.duckdns.org {
    forward_auth authelia:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy homer:8080
}

# --- n8n - Protegido pelo Authelia ---
n8n.galvani4987.duckdns.org {
    forward_auth authelia:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy n8n:5678 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}

# Adicione outros serviços protegidos aqui da mesma forma
# Ex: waha.galvani4987.duckdns.org { ... }
```

**Explicação:**
*   Um novo bloco é adicionado para `authelia.galvani4987.duckdns.org`, que simplesmente faz proxy reverso para o container Authelia.
*   Para cada serviço que você quer proteger (Homer, n8n, etc.), a diretiva `forward_auth` é adicionada.
    *   `authelia:9091`: Endereço do serviço Authelia (container_name:port).
    *   `uri /api/authz/forward-auth`: Endpoint de autorização do Authelia.
    *   `copy_headers`: Passa informações do usuário autenticado para o serviço backend (opcional, mas útil).

## 6. Implantação

1.  **Gere Hashes de Senha:** Use o comando `docker run --rm -it authelia/authelia:latest authelia crypto hash generate argon2` para cada usuário que você definiu em `users.yml` e atualize os campos `password` com os hashes gerados.
2.  **Verifique o `.env`:** Certifique-se de que todas as novas variáveis `AUTHELIA_*` no `.env` estão definidas com valores seguros e corretos.
3.  **Inicie/Atualize os Serviços:**
    No diretório raiz do projeto:
    ```bash
    docker compose up -d --remove-orphans authelia
    ```
    (O `--remove-orphans` é útil se você estiver atualizando uma configuração existente).
    Se você fez alterações no `config/Caddyfile`, recarregue o Caddy:
    ```bash
    docker compose exec -w /etc/caddy caddy caddy reload
    ```

## 7. Verificação e Configuração Inicial

1.  **Logs do Docker:**
    ```bash
    docker compose logs authelia
    docker compose logs caddy
    docker compose logs redis
    docker compose logs postgres
    ```
    Procure por erros. Authelia deve logar a conexão bem-sucedida com Redis e PostgreSQL.
2.  **Acesse o Portal Authelia:**
    Abra `https://authelia.galvani4987.duckdns.org` no seu navegador. Você deve ver a página de login do Authelia.
3.  **Primeiro Login:**
    *   Tente fazer login com o usuário e senha (a senha original, não o hash) que você configurou em `users.yml`.
    *   Na primeira vez, Authelia provavelmente pedirá para você registrar um dispositivo de autenticação de dois fatores (2FA). O método padrão é TOTP (Time-based One-Time Password) usando um aplicativo como Google Authenticator ou Authy.
    *   Siga as instruções para escanear o QR code e configurar o 2FA.
    *   Se você configurou o notificador `filesystem`, o link de registro/confirmação pode ser encontrado no arquivo `/config/notifications.txt` dentro do volume do Authelia (ou seja, `config/authelia/notifications.txt` no host).
4.  **Teste de Acesso a Serviço Protegido:**
    *   Tente acessar um serviço protegido, por exemplo, `https://galvani4987.duckdns.org` (Homer) ou `https://n8n.galvani4987.duckdns.org`.
    *   Você deve ser redirecionado para o portal Authelia para login.
    *   Após o login bem-sucedido (incluindo 2FA, se configurado), você deve ser redirecionado de volta ao serviço solicitado.
5.  **SSO:** Após logar uma vez, o acesso a outros serviços protegidos no mesmo domínio deve ser transparente (SSO).

## 8. Próximos Passos no Roadmap

Com o Authelia implantado e minimamente verificado:
*   Marque as etapas "3.B.1 Pesquisa", "3.B.2 Configuração", "3.B.3 Implantação" e "3.B.4 Verificação" como `[✅]` no `ROADMAP.md`.
*   Prossiga para a configuração do Waha (Fase 3.C) ou outros serviços.
*   Considere configurar um notificador SMTP para produção.
*   Refine as políticas de `access_control` no `configuration.yml` do Authelia para maior granularidade se necessário.

Este tutorial cobriu os passos essenciais para colocar o Authelia em funcionamento. A configuração do Authelia pode ser muito extensa. Consulte a [documentação oficial do Authelia](https://www.authelia.com/configuration/prologue/introduction/) para todas as opções e funcionalidades avançadas.
```
