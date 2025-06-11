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

## 🏛️ Estrutura do Repositório

* `docker-compose.yml`: Arquivo principal que define todos os serviços, redes e volumes Docker.
* `Caddyfile`: Arquivo de configuração para o proxy reverso Caddy.
* `.env`: Arquivo para armazenar variáveis de ambiente e segredos (este arquivo **não deve** ser enviado para o Git).
* `README.md`: Este arquivo.
* `ROADMAP.md`: O passo a passo detalhado da implantação.

## ⚙️ Como Usar

1.  **Pré-requisitos:** Um servidor com Ubuntu 24.04, Docker e Docker Compose instalados. O DNS do domínio deve apontar para o IP do servidor.
2.  Clone este repositório: `git clone git@github.com:galvani4987/docker-stack.git`
3.  Configure o arquivo `.env` com as senhas e variáveis necessárias.
4.  Inicie a pilha de serviços: `docker compose up -d`
