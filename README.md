# Docker Stack - Servidor VPS

Este repositório contém a configuração completa para implantar uma pilha de serviços de auto-hospedagem (self-hosted) em um servidor VPS (Ubuntu 24.04), utilizando Docker e Docker Compose.

O objetivo é criar uma configuração padronizada, segura, versionada e facilmente replicável.

## 🎯 Status Atual do Projeto

Este projeto está em desenvolvimento ativo. Atualmente, os scripts de bootstrap, limpeza e manutenção (`manter_ativo.sh`) estão funcionais. Os serviços base como Caddy e PostgreSQL estão operacionais, e a configuração inicial do n8n via Docker Compose está presente.

O serviço Waha está em fase de planejamento e implementação. Outros serviços como Cockpit, n8n, Caddy e PostgreSQL já estão operacionais. Para detalhes sobre o progresso e as próximas etapas, consulte nosso [ROADMAP.md](ROADMAP.md).

## 🔐 Fluxo de Acesso e Segurança

Este ambiente opera com Caddy como o ponto de entrada principal, fornecendo HTTPS automático para todos os serviços.
1. O acesso aos serviços é feito diretamente através de seus respectivos subdomínios, por exemplo, `https://n8n.galvani4987.duckdns.org`.
2. A segurança de cada serviço individual (login, etc.) é gerenciada pelo próprio serviço.

## 🚀 Serviços Planejados (Stack Final)

A pilha de serviços **inclui** os seguintes componentes, acessados através do Caddy:

* **Caddy:** Proxy reverso moderno e automático com HTTPS. É o portão de entrada para todos os serviços. (Já operacional)
* **PostgreSQL:** Banco de dados relacional robusto para aplicações. (Já operacional)
* **n8n:** Plataforma de automação de fluxos de trabalho. (Ex: [https://n8n.galvani4987.duckdns.org](https://n8n.galvani4987.duckdns.org)).
* **Waha:** API HTTP para integração com o WhatsApp **(a ser implementado)** (Ex: [https://waha.galvani4987.duckdns.org](https://waha.galvani4987.duckdns.org)).
* **Cockpit:** Interface para gerenciamento do servidor host (Instalado pelo bootstrap.sh; acesso direto via https://IP_DO_SERVIDOR:9090)

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

4.  **Inicie a Pilha Docker:**
    Com tudo configurado, inicie todos os serviços:
    ```bash
    docker compose up -d
    ```

5.  **Configurações Manuais Pós-Instalação:**
    * **Cron Job (Keep-Alive):** Configure o cron job para o script de atividade:
        ```bash
        crontab -e
        # Adicione a linha:
        0 * * * * /home/ubuntu/docker-stack/scripts/manter_ativo.sh
        ```
    * **Firewall Oracle Cloud:** Libere as portas 80 e 443 no painel da Oracle Cloud

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

### Problema: Serviços não se comunicam entre si ou com o exterior

Se os containers Docker não conseguem se comunicar entre si ou com a internet:

*   **Inspecione a Rede Docker:**
    *   Verifique se todos os serviços relevantes estão conectados à mesma rede Docker (`app-network` neste projeto).
    ```bash
    docker network inspect app-network
    ```
    *   Confirme se os containers aparecem listados na seção "Containers" da saída do comando.

*   **Teste a conectividade interna:**
    *   Você pode testar a resolução de nome e a conectividade entre containers usando `ping` ou `curl` de dentro de um container.
    *   Primeiro, acesse o shell de um container (ex: o container do Caddy):
        ```bash
        docker compose exec caddy sh
        ```
    *   Dentro do container, tente pingar outro serviço pelo nome definido no `docker-compose.yml` (ex: `ping postgres` ou `ping n8n`).
        ```sh
        # Dentro do container do Caddy
        ping postgres
        ping n8n
        ```
    *   *Nota: Algumas imagens minimalistas podem não incluir `ping` ou `curl`. Use um container que possua essas ferramentas ou instale-as temporariamente se necessário e possível.*

*   **Verifique as regras de firewall do host:**
    *   Embora o Docker gerencie suas próprias regras de iptables, configurações restritivas de UFW ou firewalls externos podem interferir. Assegure-se de que as políticas `FORWARD` não estejam bloqueando o tráfego entre redes Docker ou para o exterior.

*   **Consulte os logs dos serviços envolvidos:**
    *   Logs específicos dos containers podem indicar problemas de configuração de rede, erros de resolução de nome, ou falhas ao tentar estabelecer conexões.
    ```bash
    docker compose logs nome_do_servico_1 nome_do_servico_2
    ```

## 🤝 Contribuição
Contribuições são bem-vindas! Siga o fluxo:
1. Fork do repositório
2. Crie um branch para sua feature (`git checkout -b feature/awesome-feature`)
3. Commit suas mudanças (`git commit -am 'Add awesome feature'`)
4. Push para o branch (`git push origin feature/awesome-feature`)
5. Abra um Pull Request

## 📄 Licença
Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.
