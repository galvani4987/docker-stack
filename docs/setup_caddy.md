# Tutorial: Configurando o Caddy Reverse Proxy

Este tutorial descreve a configuração do Caddy Web Server no projeto Docker Stack VPS. Caddy atua como o reverse proxy principal, gerenciando o tráfego SSL/TLS (HTTPS automático) para todos os serviços expostos publicamente e integrando-se com o Authelia para autenticação.

A configuração base do Caddy já está definida nos arquivos `docker-compose.yml` e `config/Caddyfile` do projeto, estabelecida durante a Fase 1.B do [ROADMAP.md](../../ROADMAP.md).

## 1. Visão Geral da Configuração do Caddy

*   **Imagem Docker:** `caddy:alpine` (versão específica, ex: `caddy:2.10-alpine`, usando Alpine Linux para um tamanho reduzido).
*   **Função Principal:** Servir como o ponto de entrada para todos os serviços web, fornecendo HTTPS automático e roteando o tráfego para os containers apropriados.
*   **Integração com Authelia:** Utiliza a diretiva `forward_auth` para delegar decisões de autenticação ao Authelia antes de permitir acesso aos serviços protegidos.
*   **Configuração:** Gerenciada primariamente através do arquivo `Caddyfile`.
*   **Persistência:** Volumes Docker são usados para persistir certificados TLS e outras configurações/dados do Caddy.

## 2. Variáveis de Ambiente (`.env`)

Para a configuração do Caddy neste projeto, o email para os certificados SSL é configurado usando uma variável de ambiente. O arquivo `config/Caddyfile` utiliza `${CADDY_EMAIL}` no bloco de opções globais, e esta variável deve ser definida no seu arquivo `.env`.

**`.env` (exemplo de variável):**
```env
CADDY_EMAIL=seu_email@exemplo.com
```

**`config/Caddyfile` (trecho do bloco global):**
```caddy
{
    email ${CADDY_EMAIL}
}
```
Esta abordagem permite que o email seja configurado de forma flexível sem modificar diretamente o `Caddyfile`.

**Como funciona:**
O email utilizado para o registro de certificados SSL (ACME) é configurado dinamicamente usando a variável de ambiente `CADDY_EMAIL`. No arquivo `Caddyfile`, você vê a diretiva `email ${CADDY_EMAIL}` (as chaves `{}` podem ser opcionais em algumas sintaxes do Caddy, mas a forma `${VAR}` é a interpolação padrão de variável de ambiente). Para que isso funcione:
1.  Certifique-se de que a variável `CADDY_EMAIL` está definida com seu endereço de email no arquivo `.env` na raiz do projeto (ex: `CADDY_EMAIL=seuemail@dominio.com`). Este é um passo **obrigatório**.
2.  A configuração do serviço `caddy` no arquivo `docker-compose.yml` inclui a diretiva `env_file: - .env`. Esta linha é crucial, pois faz com que todas as variáveis definidas no seu arquivo `.env` sejam carregadas para dentro do ambiente do container do Caddy.
3.  Com a variável `CADDY_EMAIL` disponível dentro do container, o Caddy pode então substituir o placeholder `${CADDY_EMAIL}` no `Caddyfile` pelo valor real fornecido, usando-o para o processo de obtenção de certificados SSL.

Certifique-se de que a variável `CADDY_EMAIL` esteja corretamente definida no seu arquivo `.env` na raiz do projeto.

## 3. Configuração no `docker-compose.yml`

A definição do serviço `caddy` no arquivo `docker-compose.yml` é:

```yaml
services:
  caddy:
    image: caddy:alpine # Ou uma versão específica como caddy:2.10-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"   # Para desafios HTTP ACME e redirecionamento HTTP->HTTPS
      - "443:443" # Para tráfego HTTPS
      - "443:443/udp" # Para HTTP/3 (QUIC)
    volumes:
      # Monta o diretório config/ para que Caddy possa ler o Caddyfile em /etc/caddy/Caddyfile
      # Esta é a forma recomendada em vez de montar o arquivo Caddyfile diretamente.
      - ./config:/etc/caddy
      # Volume para armazenar certificados TLS e outros dados persistentes do Caddy
      - caddy_data:/data
      # Volume para armazenar a configuração ativa do Caddy e outros estados internos
      - caddy_config:/config
    networks:
      - app-network
    # cap_add: # Opcional, para melhor performance do HTTP/3
    #   - NET_ADMIN
```

**Pontos Chave da Configuração:**
*   **`image: caddy:alpine`**: Especifica a imagem Docker.
*   **`ports:`**: Mapeia as portas HTTP e HTTPS (TCP e UDP para HTTP/3) do host para o container.
*   **`volumes:`**:
    *   `./config:/etc/caddy`: **Importante:** Monta o diretório local `./config` (que deve conter seu `Caddyfile`) para `/etc/caddy` dentro do container. Caddy irá procurar por `/etc/caddy/Caddyfile` por padrão. Esta abordagem é preferível a montar o arquivo diretamente para garantir que as recargas de configuração funcionem corretamente com todos os editores de texto.
    *   `caddy_data:/data`: Volume nomeado para persistir dados críticos como certificados TLS.
    *   `caddy_config:/config`: Volume nomeado para persistir a configuração ativa do Caddy e outros estados.
*   **`cap_add: - NET_ADMIN` (Opcional):** Pode ser descomentado para potencialmente melhorar a performance do HTTP/3, permitindo que o Caddy ajuste os buffers de UDP. Não é estritamente necessário.

Lembre-se de declarar os volumes nomeados na seção global `volumes` no final do `docker-compose.yml`:
```yaml
volumes:
  # ... outros volumes ...
  caddy_data:
  caddy_config:
```

## 4. Estrutura do `Caddyfile`

O arquivo `config/Caddyfile` define como o Caddy gerencia seus sites. Ele consiste em um bloco global de opções e blocos individuais para cada site (domínio/subdomínio).

**Exemplo da Estrutura Geral (conforme configurado para o projeto):**

```caddy
{
    # Email para registro de certificados SSL com Let's Encrypt
    # Esta variável é obtida do arquivo .env
    email ${CADDY_EMAIL}

    # Outras opções globais podem ser adicionadas aqui
    # ex: acme_dns duckdns seu_token_duckdns
    # default_sni seu_dominio_principal.com
}

# --- Portal Authelia ---
# (authelia.galvani4987.duckdns.org)
authelia.galvani4987.duckdns.org {
    reverse_proxy authelia:9091 # 'authelia' é o nome do serviço Authelia no Docker Compose
}

# --- Homer (Dashboard Principal) - Protegido pelo Authelia ---
# (galvani4987.duckdns.org)
galvani4987.duckdns.org {
    forward_auth authelia:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy homer:8080 # 'homer' é o nome do serviço Homer
}

# --- n8n - Protegido pelo Authelia ---
# (n8n.galvani4987.duckdns.org)
n8n.galvani4987.duckdns.org {
    forward_auth authelia:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy n8n:5678 { # 'n8n' é o nome do serviço n8n
        # Headers adicionais úteis para n8n
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-Proto {scheme}
    }
}

# --- WAHA (WhatsApp API) - Protegido pelo Authelia ---
# (waha.galvani4987.duckdns.org)
waha.galvani4987.duckdns.org {
    forward_auth authelia:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy waha:3000 # 'waha' é o nome do serviço WAHA
}

# Adicione outros serviços aqui seguindo o mesmo padrão.
```

**Diretivas Chave:**
*   **Bloco Global `{...}`**: Define opções que se aplicam a todos os sites, como o email para ACME (Let's Encrypt).
*   **Bloco de Site `dominio.com { ... }`**: Define a configuração para um domínio específico.
*   **`reverse_proxy <upstream_address>`**: Envia o tráfego para um serviço backend (outro container). Ex: `reverse_proxy homer:8080`.
*   **`forward_auth <auth_gateway_address> { ... }`**:
    *   Envia uma sub-requisição para o gateway de autenticação (Authelia).
    *   `uri /api/authz/forward-auth`: Endpoint padrão do Authelia para verificar a autenticação.
    *   `copy_headers ...`: Copia headers com informações do usuário do Authelia para a requisição que vai para o serviço backend.
*   **Placeholders:** Caddy usa placeholders como `{host}`, `{remote}`, `{scheme}` que são preenchidos dinamicamente.

## 5. HTTPS Automático

Caddy gerencia automaticamente certificados TLS (HTTPS) para todos os sites definidos no `Caddyfile`, desde que:
1.  Os registros DNS para os domínios estejam apontando corretamente para o IP público do servidor onde o Caddy está rodando.
2.  O Caddy consiga acessar a internet nas portas 80 e 443 para completar os desafios ACME (ex: HTTP-01, TLS-ALPN).

Não há necessidade de configurar manualmente os certificados.

## 6. Recarregando a Configuração do Caddy

Se você fizer alterações no `config/Caddyfile` enquanto o Caddy já estiver rodando, você pode recarregar a configuração sem parar o servidor (graceful reload):

```bash
docker compose exec -w /etc/caddy caddy caddy reload
```
*   `docker compose exec caddy`: Executa um comando dentro do container `caddy`.
*   `-w /etc/caddy`: Define o diretório de trabalho para `/etc/caddy` (onde o `Caddyfile` está localizado dentro do container).
*   `caddy reload`: O comando do Caddy para recarregar a configuração.

## 7. Verificação (Conforme Roadmap Fase 1.B)

A verificação do Caddy envolve:
1.  **Iniciar o serviço:**
    ```bash
    docker compose up -d caddy
    ```
2.  **Verificar logs:**
    ```bash
    docker compose logs caddy
    ```
    Procure por mensagens indicando que os sites foram servidos, certificados foram obtidos (se for a primeira vez), e que está pronto para aceitar conexões.
3.  **Testar acesso:** Tentar acessar os domínios configurados (ex: `https://galvani4987.duckdns.org`) no navegador para confirmar que o HTTPS está funcionando e o conteúdo esperado (ou o portal Authelia) é exibido.

## Conclusão

Caddy é um componente central e poderoso desta pilha, simplificando o gerenciamento de reverse proxy e SSL/TLS. Sua configuração através do `Caddyfile` é flexível e permite integrar facilmente com serviços de autenticação como o Authelia. Para mais detalhes sobre todas as diretivas e funcionalidades do Caddy, consulte a [documentação oficial do Caddy](https://caddyserver.com/docs/).
```
