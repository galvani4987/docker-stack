# Docker Stack - Servidor VPS

Este repositório contém a configuração completa para implantar uma pilha de serviços de auto-hospedagem (self-hosted) em um servidor VPS (Ubuntu 24.04), utilizando Docker e Docker Compose.

O objetivo é criar uma configuração padronizada, segura, versionada e facilmente replicável.

## 🔐 Fluxo de Acesso e Segurança

Este ambiente foi projetado com um modelo de segurança centralizado:

1.  O ponto de entrada principal é o domínio raiz: **https://galvani4987.duckdns.org**.
2.  Todo o acesso é protegido e gerenciado pelo **Authelia**, que exige login com usuário, senha e **Autenticação de Dois Fatores (2FA/TOTP)** via um aplicativo como o Google Authenticator.
3.  Após a autenticação bem-sucedida, o usuário é direcionado para o dashboard principal **Homer**.
4.  Uma vez logado, o acesso aos outros serviços (como n8n, waha, etc.) é liberado através de Single Sign-On (SSO), sem a necessidade de um novo login.

## 🚀 Serviços Implantados

A pilha de serviços inclui:

* **Caddy:** Proxy reverso moderno e automático com HTTPS. É o portão de entrada para todos os serviços.
* **PostgreSQL:** Banco de dados relacional robusto para aplicações.
* **Redis:** Banco de dados em memória ultrarrápido, utilizado para o gerenciamento de sessões do Authelia.
* **Authelia:** O portal de segurança que provê autenticação unificada (SSO) e 2FA (Ex: `authelia.galvani4987.duckdns.org`).
* **Homer:** Dashboard Principal, acessível no domínio raiz (`https://galvani4987.duckdns.org`) após o login.
* **n8n:** Plataforma de automação de fluxos de trabalho, protegida pelo Authelia (Ex: `n8n.galvani4987.duckdns.org`).
* **Waha:** API HTTP para integração com o WhatsApp, protegida pelo Authelia (Ex: `waha.galvani4987.duckdns.org`).
* **Cockpit:** Interface para gerenciamento do servidor host (Acesso direto via `https://IP_DO_SERVIDOR:9090`).

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
    Este script instalará dependências do servidor (como Cockpit) e preparará o ambiente.
    ```bash
    sudo bash bootstrap.sh
    ```

3.  **Edite seus Segredos:**
    O script de bootstrap criou o arquivo `.env`. Edite-o com suas senhas e tokens.
    ```bash
    nano .env
    ```

4.  **Inicie a Pilha Docker:**
    Com tudo configurado, inicie todos os serviços.
    ```bash
    docker compose up -d
    ```

5.  **Configurações Manuais Pós-Instalação:**
    * **Cron Job (Keep-Alive):** Se desejar, configure o cron job para o script de atividade:
        ```bash
        # Abre o editor de cron jobs
        crontab -e
        # Adicione a linha e salve:
        0 * * * * /home/ubuntu/scripts/manter_ativo.sh
        ```
