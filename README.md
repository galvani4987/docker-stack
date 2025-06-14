# Docker Stack - Servidor VPS

Este repositório contém a configuração completa para implantar uma pilha de serviços de auto-hospedagem (self-hosted) em um servidor VPS (Ubuntu 24.04), utilizando Docker, Docker Compose, e **Authentik para Single Sign-On (SSO) e gerenciamento de identidade.**

O objetivo é criar uma configuração padronizada, segura, versionada e facilmente replicável, onde **Authentik atua como o portal de entrada principal e o provedor de identidade para os demais serviços.**

## 🎯 Status Atual do Projeto

Este projeto está em desenvolvimento ativo. Atualmente, os scripts de bootstrap, limpeza e manutenção (`manter_ativo.sh`) estão funcionais. Os serviços base como Caddy e PostgreSQL estão operacionais, e a configuração inicial do n8n via Docker Compose está presente.

O serviço Waha está em fase de planejamento e implementação. Outros serviços como Cockpit, n8n, Caddy e PostgreSQL já estão operacionais. Para detalhes sobre o progresso e as próximas etapas, consulte nosso [ROADMAP.md](ROADMAP.md).

## 🔐 Fluxo de Acesso e Segurança

Este ambiente opera com **Authentik como o provedor de identidade central e Caddy como o reverse proxy principal**, fornecendo HTTPS automático para todos os serviços.
1. O acesso ao domínio principal (`https://{$DOMAIN_NAME}`) e a todos os serviços protegidos (n8n, Cockpit, Waha, etc.) é gerenciado pelo Authentik.
2. Ao tentar acessar um serviço, o usuário é redirecionado para o Authentik para login (se ainda não estiver logado).
3. Após a autenticação bem-sucedida (que pode incluir Google OAuth), o usuário é redirecionado de volta ao serviço solicitado.
4. O Authentik também serve como a página de destino principal do stack em `https://{$DOMAIN_NAME}`.

## 🚀 Serviços da Stack

A pilha de serviços **inclui** os seguintes componentes:

*   **Authentik:** Provedor de Identidade e SSO. Gerencia o acesso a todos os outros aplicativos.
    *   `authentik-server`: O serviço principal do Authentik.
    *   `authentik-worker`: Processos em segundo plano para o Authentik.
    *   `authentik-postgres`: Banco de dados dedicado para o Authentik.
    *   `authentik-redis`: Cache dedicado para o Authentik.
    *   `authentik_proxy_n8n`: Outpost do Authentik para proteger o n8n.
    *   `authentik_proxy_cockpit`: Outpost do Authentik para proteger o Cockpit.
    *   `authentik_proxy_waha`: Outpost do Authentik para proteger o Waha.
*   **Caddy:** Proxy reverso moderno e automático com HTTPS. Roteia o tráfego para o Authentik e seus outposts.
*   **PostgreSQL (Principal):** Banco de dados relacional robusto para aplicações como n8n.
*   **n8n:** Plataforma de automação de fluxos de trabalho. Acesso via `https://n8n.{$DOMAIN_NAME}` (protegido pelo Authentik).
*   **Waha:** API HTTP para integração com o WhatsApp. Acesso via `https://waha.{$DOMAIN_NAME}` (protegido pelo Authentik).
*   **Cockpit:** Interface para gerenciamento do servidor host. Acesso via `https://cockpit.{$DOMAIN_NAME}` (protegido pelo Authentik).

*Nota: Consulte o [ROADMAP.md](ROADMAP.md) para o status atual de implementação de cada serviço.*

## 🛠️ Scripts de Gerenciamento

Dois scripts essenciais para gerenciamento do servidor:

### `bootstrap.sh`
Prepara um novo servidor com todas as dependências necessárias:
```bash
sudo bash bootstrap.sh
```

### `clean-server.sh`
Reseta completamente o servidor para estado limpo (removendo Docker, resetando firewall, etc.):
```bash
sudo bash clean-server.sh
```

### `manter_ativo.sh` (Cron Job)
Script para manter serviços ativos (executado via cron):
```bash
0 * * * * /home/ubuntu/docker-stack/scripts/manter_ativo.sh
```

## ⚙️ Implantação em um Novo Servidor

Este repositório é projetado para uma implantação rápida e semi-automatizada.

**Pré-requisitos:**
* Um servidor limpo com Ubuntu 24.04.
* Acesso root/sudo.
* O DNS do seu domínio (`galvani4987.duckdns.org`) já apontando para o IP do novo servidor.

**Passos de Implantação:**

1.  **Clone o Repositório:**
    ```bash
    # Instale o git primeiro, se necessário: sudo apt update && sudo apt install git -y
    git clone git@github.com:galvani4987/docker-stack.git
    cd docker-stack
    ```

2.  **Execute o Script de Bootstrap:**
    Este script instalará dependências do servidor e preparará o ambiente:
    ```bash
    sudo bash bootstrap.sh
    ```
    *Nota: Após a execução, o usuário `ubuntu` é adicionado ao grupo `docker`. Pode ser necessário sair e logar novamente na sessão SSH para que as permissões do Docker sejam aplicadas sem `sudo`.*

3.  **Edite seus Segredos:**
    O script de bootstrap criou o arquivo `.env`. Edite-o com suas senhas e tokens:
    ```bash
    nano .env
    ```
    **Importante:** Certifique-se de definir todas as variáveis `POSTGRES_*` para o banco de dados principal do n8n, e todas as novas variáveis `AUTHENTIK_*` (senhas, chaves secretas, tokens de outpost, configurações de email) conforme detalhado no `.env.example` e na documentação do Authentik.

4.  **Inicie a Pilha Docker:**
    Com tudo configurado, inicie todos os serviços:
    ```bash
    docker compose up -d
    ```

5.  **Configuração Inicial do Authentik (Manual - UI):**
    Após iniciar os serviços, você precisará realizar a configuração inicial do Authentik através da interface web.
    *   **Acesse `https://{$DOMAIN_NAME}/if/flow/initial-setup/`** (substitua `{$DOMAIN_NAME}` pelo seu domínio real).
    *   Siga as instruções para criar o usuário administrador `akadmin`.
    *   **Consulte o guia detalhado `docs/setup_authentik.md`** para configurar o Google OAuth, proteger as aplicações (n8n, Cockpit, Waha) criando Providers e Outposts, e obter os `AUTHENTIK_TOKEN_*` para adicionar ao seu arquivo `.env`.
    *   **Após obter e configurar os `AUTHENTIK_TOKEN_*` no `.env`, reinicie os serviços de proxy do Authentik:**
        ```bash
        docker compose restart authentik_proxy_n8n authentik_proxy_cockpit authentik_proxy_waha
        ```

6.  **Configurações Manuais Pós-Instalação (Outras):**
    * **Cron Job (Keep-Alive):** Configure o cron job para o script de atividade:
        ```bash
        crontab -e
        # Adicione a linha:
        0 * * * * /home/ubuntu/docker-stack/scripts/manter_ativo.sh
        ```
    * **Firewall Oracle Cloud:** Libere as portas 80 e 443 no painel da Oracle Cloud (se aplicável).

## 🔄 Gerenciamento Diário

Comandos úteis para operação do sistema:

| Comando | Descrição |
|---------|-----------|
| `docker compose up -d` | Iniciar todos os serviços |
| `docker compose stop` | Parar todos os serviços |
| `docker compose logs -f` | Ver logs em tempo real |
| `docker compose pull` | Atualizar imagens dos serviços |
| `sudo bash clean-server.sh` | Reset completo do servidor |
| `sudo ufw status` | Verificar status do firewall |
| `docker compose logs authentik-server authentik-worker` | Ver logs do Authentik |
| `docker compose logs authentik_proxy_n8n` | Ver logs de um outpost específico |

## Variáveis de Ambiente Essenciais (.env)

As seguintes variáveis devem ser configuradas no seu arquivo `.env`:

-   `DOMAIN_NAME=your.domain.com`
-   `CADDY_EMAIL=your_email@example.com`

-   `POSTGRES_DB=n8n`
-   `POSTGRES_USER=n8n`
-   `POSTGRES_PASSWORD=<STRONG_PASSWORD_FOR_N8N_DB>`

-   `N8N_DB_TYPE=postgres`
-   `N8N_DB_POSTGRESDB_HOST=postgres`
-   `N8N_DB_POSTGRESDB_PORT=5432`
-   `N8N_DB_POSTGRESDB_USER=${POSTGRES_USER}`
-   `N8N_DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}`
-   `N8N_DB_POSTGRESDB_DATABASE=${POSTGRES_DB}`
-   `N8N_WEBHOOK_URL=https://n8n.{$DOMAIN_NAME}`
-   `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true`
-   `N8N_RUNNERS_ENABLED=false`

-   `WHATSAPP_API_KEY=<YOUR_WAHA_API_KEY>`
-   `WAHA_BASE_URL=https://waha.{$DOMAIN_NAME}`
-   `WHATSAPP_HOOK_URL=https://n8n.{$DOMAIN_NAME}/webhook/whatsapp`
-   `WHATSAPP_HOOK_EVENTS=message,ack`
-   `WAHA_DEBUG_MODE=false`
-   `WAHA_LOG_LEVEL=info`

-   `AUTHENTIK_POSTGRES_DB=authentik`
-   `AUTHENTIK_POSTGRES_USER=authentik`
-   `AUTHENTIK_POSTGRES_PASSWORD=<STRONG_PASSWORD_FOR_AUTHENTIK_DB>`
-   `AUTHENTIK_SECRET_KEY=<STRONG_SECRET_KEY_FOR_AUTHENTIK_APP>`

-   `AUTHENTIK_EMAIL_HOST=smtp.example.com`
-   `AUTHENTIK_EMAIL_PORT=587`
-   `AUTHENTIK_EMAIL_USERNAME=user@example.com`
-   `AUTHENTIK_EMAIL_PASSWORD=<YOUR_SMTP_PASSWORD>`
-   `AUTHENTIK_EMAIL_USE_TLS=true`
-   `AUTHENTIK_EMAIL_USE_SSL=false`
-   `AUTHENTIK_EMAIL_FROM=authentik@{$DOMAIN_NAME}`

-   `AUTHENTIK_TOKEN_N8N=<AUTHENTIK_OUTPOST_TOKEN_FOR_N8N>`
-   `AUTHENTIK_TOKEN_COCKPIT=<AUTHENTIK_OUTPOST_TOKEN_FOR_COCKPIT>`
-   `AUTHENTIK_TOKEN_WAHA=<AUTHENTIK_OUTPOST_TOKEN_FOR_WAHA>`

## 🚨 Troubleshooting

Esta seção aborda problemas comuns e suas possíveis soluções.

### Problema: Certificados SSL não são gerados pelo Caddy

Se você estiver enfrentando problemas com a emissão de certificados SSL (HTTPS):

*   **Verifique a propagação do DNS:**
    *   Certifique-se de que os registros DNS do seu domínio (e subdomínios) estão corretamente apontados para o endereço IP público do servidor.
    *   A propagação de DNS pode levar algum tempo. Utilize ferramentas online como `whatsmydns.net` para verificar o status da propagação para os tipos de registro A ou CNAME.

*   **Analise os logs do Caddy:**
    *   Os logs do Caddy fornecem informações detalhadas sobre o processo de obtenção de certificados.
    ```bash
    docker compose logs caddy
    ```
    *   Procure por mensagens de erro relacionadas a desafios ACME, timeouts, ou problemas de conectividade.

*   **Confira as configurações do Caddyfile:**
    *   Verifique se os nomes de domínio no seu `config/Caddyfile` estão corretos e correspondem aos seus registros DNS.
    *   Certifique-se de que o email fornecido para a Let's Encrypt no Caddyfile é válido.

*   **Firewall e Portas:**
    *   Caddy precisa que as portas 80 (para desafios HTTP) e 443 (para TLS-ALPN) estejam acessíveis publicamente. Verifique o firewall do seu provedor de nuvem e o UFW no servidor:
    ```bash
    sudo ufw status
    ```

### Problema: Serviços não se comunicam entre si ou com o exterior (Pós-Authentik)

Com a introdução do Authentik, a comunicação passa pelos outposts.

*   **Verifique os logs do Outpost:** Se um aplicativo não estiver acessível, o primeiro lugar para verificar é o log do outpost correspondente (ex: `docker compose logs authentik_proxy_n8n`).
    *   Procure por erros de token, problemas de conexão com o `AUTHENTIK_HOST` ou com o serviço interno.
*   **Verifique os logs do Authentik Server/Worker:** `docker compose logs authentik-server authentik-worker`.
*   **Configuração do Provider no Authentik UI:**
    *   **External Host:** Deve corresponder exatamente ao URL que o usuário acessa (ex: `https://n8n.{$DOMAIN_NAME}`).
    *   **Internal Host:** Deve ser o nome do serviço Docker e a porta correta (ex: `http://n8n:5678`). O outpost precisa conseguir resolver e alcançar este host.
*   **Token do Outpost:** Certifique-se de que o token no arquivo `.env` (`AUTHENTIK_TOKEN_N8N`, etc.) é exatamente o mesmo fornecido pelo Authentik UI ao criar/editar o outpost. Reinicie o outpost após qualquer alteração no token.
*   **`AUTHENTIK_HOST` nos Outposts:** Verifique se a variável `AUTHENTIK_HOST` (ex: `https://auth.{$DOMAIN_NAME}`) nos serviços de outpost no `docker-compose.yml` está correta e acessível de dentro da rede Docker.

*   **Inspecione a Rede Docker:**
    *   Verifique se todos os serviços (Authentik server/worker, outposts, aplicações) estão conectados à mesma rede Docker (`app-network` neste projeto).
    ```bash
    docker network inspect app-network
    ```
*   **Teste a conectividade interna (do outpost para a aplicação):**
    *   Acesse o shell de um container de outpost (ex: `authentik_proxy_n8n`):
        ```bash
        docker compose exec authentik_proxy_n8n sh
        ```
    *   Dentro do container, tente usar `curl` para acessar o serviço interno que ele deveria proteger (ex: `curl http://n8n:5678`).
        ```sh
        # Dentro do container authentik_proxy_n8n
        curl http://n8n:5678
        ```
    *   Se isso falhar, há um problema de rede entre o outpost e o serviço de destino, ou o serviço de destino não está funcionando.

*   **Verifique as regras de firewall do host:**
    *   Normalmente não é um problema para comunicação interna do Docker, mas configurações muito restritivas podem interferir.

*   **Consulte os logs dos serviços envolvidos:**
    *   Logs específicos dos containers (aplicação, outpost, authentik-server) são cruciais.

## 🤝 Contribuição
Contribuições são bem-vindas! Siga o fluxo:
1. Fork do repositório
2. Crie um branch para sua feature (`git checkout -b feature/awesome-feature`)
3. Commit suas mudanças (`git commit -am 'Add awesome feature'`)
4. Push para o branch (`git push origin feature/awesome-feature`)
5. Abra um Pull Request

## 📄 Licença
Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.
