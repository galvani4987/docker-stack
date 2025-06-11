# Docker Stack - Servidor VPS

Este repositório contém a configuração completa para implantar uma pilha de serviços de auto-hospedagem (self-hosted) em um servidor VPS (Ubuntu 24.04), utilizando Docker e Docker Compose.

O objetivo é criar uma configuração padronizada, segura, versionada e facilmente replicável para os serviços rodando sob o domínio **galvani4987.duckdns.org**.

## 🚀 Serviços Implantados

A pilha de serviços inclui:

* **Caddy:** Proxy reverso moderno e automático com HTTPS.
* **PostgreSQL:** Banco de dados relacional robusto.
* **n8n:** Plataforma de automação de fluxos de trabalho (Ex: `n8n.galvani4987.duckdns.org`).
* **Homer:** Um dashboard simples e estático para acesso rápido aos serviços (Ex: `home.galvani4987.duckdns.org`).
* **Waha:** Uma API HTTP para integração com o WhatsApp (Ex: `waha.galvani4987.duckdns.org`).
* **Cockpit:** Interface para gerenciamento do servidor host (Acesso via `http://IP_DO_SERVIDOR:9090`).
* **Althelia:** (Definição pendente de documentação).

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
