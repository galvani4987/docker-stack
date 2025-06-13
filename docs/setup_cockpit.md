# Configuração do Cockpit com Caddy e Authelia

## 1. Introdução

O Cockpit é uma interface de gerenciamento de servidor leve e fácil de usar que permite administrar seu servidor Linux via navegador web. Neste projeto, o Cockpit é instalado diretamente no host e acessado de forma segura através do Caddy (como proxy reverso) e protegido pelo Authelia.

## 2. Pré-requisitos

- Cockpit instalado no servidor host (o script `bootstrap.sh` deste projeto já realiza a instalação).
- Caddy configurado e em execução.
- Authelia configurado e em execução (ou planejado para ser, conforme o `ROADMAP.md`).
- Homer configurado e em execução (ou planejado para ser, para integração no dashboard).
- DNS para `cockpit.galvani4987.duckdns.org` (ou seu domínio) apontando para o IP do servidor.

## 3. Configuração do Caddy

Adicione o seguinte bloco ao seu `config/Caddyfile` para expor o Cockpit através do subdomínio `cockpit.galvani4987.duckdns.org` e protegê-lo com Authelia:

```caddy
cockpit.galvani4987.duckdns.org {
    reverse_proxy host.docker.internal:9090 {
        header_up Host {host}
        header_up X-Real-IP {client_ip}
        header_up X-Forwarded-For {client_ip}
        header_up X-Forwarded-Proto {scheme}
    }
    forward_auth authelia:9091 { # Assegure que 'authelia:9091' é o endereço correto do seu container Authelia
        uri /api/verify?rd=https://authelia.galvani4987.duckdns.org/ # URL de redirecionamento para o portal Authelia
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
}
```

**Notas sobre a configuração do Caddy:**
- `host.docker.internal:9090`: Permite que o container Caddy acesse o serviço Cockpit rodando na porta 9090 do host. Se o Caddy não estiver rodando em Docker ou `host.docker.internal` não estiver disponível em seu ambiente Docker, você pode precisar usar o IP específico do host na rede Docker (ex: `172.17.0.1:9090`).
- O Caddy v2 lida com WebSockets automaticamente na maioria das configurações de proxy reverso, o que é necessário para o Cockpit.
- Após adicionar esta configuração, reinicie ou recarregue o Caddy: `docker compose restart caddy` (ou `docker compose exec -w /etc/caddy caddy caddy reload`).

## 4. Configuração do Authelia

Para proteger o Cockpit, adicione uma regra de controle de acesso ao arquivo `config/authelia/configuration.yml`:

```yaml
access_control:
  default_policy: deny # Assegure que esta política padrão esteja definida
  rules:
    # ... outras regras existentes ...
    - domain: "cockpit.galvani4987.duckdns.org"
      policy: two_factor # Conforme definido para Cockpit
      subject: "group:admins" # Restringe o acesso a usuários no grupo 'admins'
    # ... outras regras existentes ...
```

**Notas sobre a configuração do Authelia:**
- Certifique-se de que o domínio `cockpit.galvani4987.duckdns.org` esteja coberto pela configuração de sessão do Authelia (geralmente através de `session.cookies[0].domain: "galvani4987.duckdns.org"` no `configuration.yml`, que cobre subdomínios).
- Após modificar o `configuration.yml` do Authelia, reinicie o container: `docker compose restart authelia`.

## 5. Integração com o Homer (Dashboard)

Para adicionar um link para o Cockpit no seu dashboard Homer, edite o arquivo `config/homer/config.yml`:

```yaml
services:
  - name: "Management" # Ou o nome do grupo onde você adicionou o Cockpit
    icon: "fas fa-server"
    items:
      # ... outros itens no grupo Management ...
      - name: "Cockpit"
        icon: "fas fa-server" # Conforme definido para Cockpit
        subtitle: "Server Management Interface"
        tag: "infra"
        url: "https://cockpit.galvani4987.duckdns.org"
        target: "_blank"
      # ... outros itens no grupo Management ...
```

Após salvar as alterações no `config.yml` do Homer, reinicie o container: `docker compose restart homer` (Homer geralmente recarrega a configuração automaticamente, mas um restart garante).

## 6. Verificação

1.  Acesse `https://cockpit.galvani4987.duckdns.org` no seu navegador.
2.  Você deverá ser redirecionado para o portal do Authelia para login.
3.  Após autenticação bem-sucedida (incluindo 2FA, pois a política foi definida como `two_factor` para o grupo `admins`), você deverá ser redirecionado para a interface do Cockpit.
4.  Verifique se o Cockpit está funcionando corretamente.
5.  Verifique se o link para o Cockpit no dashboard Homer funciona e leva ao processo de autenticação/Cockpit.

## 7. Considerações de Segurança

- **Permissões do Cockpit:** O Cockpit opera com as permissões do usuário com o qual você se loga nele (usuário do sistema host). Certifique-se de que apenas usuários autorizados do sistema tenham credenciais válidas.
- **Authelia como Camada de Acesso:** O Authelia controla o *acesso* ao Cockpit via web, mas não gerencia as permissões *dentro* do Cockpit. O acesso ao Cockpit é restrito a membros do grupo `admins` do Authelia.
- **Atualizações:** Mantenha o Cockpit e o sistema operacional do host atualizados.
```
