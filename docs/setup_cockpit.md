# Configuração do Cockpit com Caddy

## 1. Introdução

O Cockpit é uma interface de gerenciamento de servidor leve e fácil de usar que permite administrar seu servidor Linux via navegador web. Neste projeto, o Cockpit é instalado diretamente no host e pode ser acessado de forma segura através do Caddy (como proxy reverso).

## 2. Pré-requisitos

- Cockpit instalado no servidor host (o script `bootstrap.sh` deste projeto já realiza a instalação).
- Caddy configurado e em execução.
- DNS para `cockpit.galvani4987.duckdns.org` (ou seu domínio) apontando para o IP do servidor.

## 3. Configuração do Caddy

Adicione o seguinte bloco ao seu `config/Caddyfile` para expor o Cockpit através do subdomínio `cockpit.galvani4987.duckdns.org`:

```caddy
cockpit.galvani4987.duckdns.org {
    reverse_proxy host.docker.internal:9090 {
        header_up Host {host}
        header_up X-Real-IP {client_ip}
        header_up X-Forwarded-For {client_ip}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

**Notas sobre a configuração do Caddy:**
- `host.docker.internal:9090`: Permite que o container Caddy acesse o serviço Cockpit rodando na porta 9090 do host. Se o Caddy não estiver rodando em Docker ou `host.docker.internal` não estiver disponível em seu ambiente Docker, você pode precisar usar o IP específico do host na rede Docker (ex: `172.17.0.1:9090`).
- O Caddy v2 lida com WebSockets automaticamente na maioria das configurações de proxy reverso, o que é necessário para o Cockpit.
- Após adicionar esta configuração, reinicie ou recarregue o Caddy: `docker compose restart caddy` (ou `docker compose exec -w /etc/caddy caddy caddy reload`).

## 4. Verificação

1.  Acesse `https://cockpit.galvani4987.duckdns.org` no seu navegador.
2.  Você deverá ser direcionado para a interface de login do Cockpit.
3.  Realize o login com as credenciais de um usuário válido do servidor host.
4.  Verifique se o Cockpit está funcionando corretamente.

## 5. Considerações de Segurança

- **Permissões do Cockpit:** O Cockpit opera com as permissões do usuário com o qual você se loga nele (usuário do sistema host). Certifique-se de que apenas usuários autorizados do sistema tenham credenciais válidas.
- **Acesso via Caddy:** O Caddy fornece uma camada de proxy reverso com HTTPS, mas não adiciona autenticação própria neste setup para o Cockpit. A autenticação é feita pelo próprio Cockpit.
- **Atualizações:** Mantenha o Cockpit e o sistema operacional do host atualizados.
```
