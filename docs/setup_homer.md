# Tutorial: Configurando o Homer Dashboard

Este tutorial guia você pela configuração e implantação do Homer, um painel de aplicativos estático, simples e elegante, como parte do projeto Docker Stack VPS. Homer servirá como o painel principal após a autenticação.

## Pré-requisitos

1.  **Serviços Essenciais Rodando:** Certifique-se de que o serviço `caddy` já esteja configurado e rodando, conforme a Fase 1.B do [ROADMAP.md](../../ROADMAP.md).
2.  **Diretório de Configuração:** Crie o diretório no host que será usado para armazenar a configuração do Homer. Conforme o `ROADMAP.md`, este será `config/homer` na raiz do projeto.
    ```bash
    mkdir -p config/homer/assets/icons
    mkdir -p config/homer/assets/tools
    # O diretório 'assets' e subdiretórios são opcionais agora, mas úteis para ícones/logos personalizados.
    # Homer pode criar um config.yml padrão se INIT_ASSETS=1 e o diretório principal for gravável.
    ```
3.  **UID/GID do Usuário:** Identifique o UID (User ID) e GID (Group ID) do usuário que irá gerenciar os arquivos de configuração do Homer no host (geralmente o usuário `ubuntu`). Execute `id ubuntu` (ou `id $USER`) no terminal do host. O padrão é frequentemente `1000:1000`.

## 1. Arquivo de Configuração do Homer (`config.yml`)

Crie o arquivo `config/homer/config.yml` com o seguinte conteúdo inicial. Este é um exemplo baseado no `ROADMAP.md`; personalize-o conforme suas necessidades.

```yaml
# config/homer/config.yml

title: "Dashboard do Servidor"
subtitle: "Meus Serviços Self-Hosted"
# documentTitle: "Meu Dashboard" # Opcional: Texto da aba do navegador
logo: "assets/logo.png" # Coloque seu logo em config/homer/assets/logo.png (ex: 72x72)
# icon: "fas fa-skull-crossbones" # Alternativa ao logo, usando Font Awesome

header: true
footer: '<p>Criado com <span class="has-text-danger">❤️</span> por <a href="https://github.com/bastienwirtz/homer" target="_blank" rel="noopener noreferrer">Homer</a> e customizado por mim!</p>'

columns: "3" # "auto" ou um número (1, 2, 3, 4, 6, 12)
connectivityCheck: true # Verifica a conectividade e recarrega em redirecionamentos (útil com Authelia)

defaults:
  layout: columns
  colorTheme: auto # auto, light, ou dark

# Para um tema mais elaborado, você pode consultar a documentação do Homer.
# theme: default

# Exemplo de mensagem no topo
# message:
#   style: "is-info"
#   title: "Bem-vindo ao seu novo dashboard!"
#   icon: "fa fa-info-circle"
#   content: "Este é um exemplo de mensagem. Você pode customizá-la ou removê-la."

links:
  - name: "n8n"
    icon: "fas fa-robot" # Ícone do Font Awesome
    url: "https://n8n.galvani4987.duckdns.org/"
    target: "_blank" # Abrir em nova aba
  # Adicione mais links para seus outros serviços aqui
  # Exemplo:
  # - name: "Serviço X"
  #   logo: "assets/tools/servico_x_logo.png" # Coloque em config/homer/assets/tools/
  #   url: "https://servicox.galvani4987.duckdns.org/"
  #   target: "_blank"

services:
  - name: "Administração"
    icon: "fas fa-server"
    items:
      - name: "Cockpit"
        icon: "fas fa-terminal"
        subtitle: "Gerenciamento do Servidor Host"
        url: "https://IP_DO_SEU_SERVIDOR:9090" # Substitua pelo IP real
        target: "_blank"
      # Adicione outros serviços de administração se necessário
```

**Notas sobre `config.yml`:**
*   **Ícones:** Homer usa Font Awesome para ícones (`icon: "fas fa-..."`). Você pode procurar ícones no site do [Font Awesome](https://fontawesome.com/search?m=free).
*   **Logos Personalizados:** Para usar logos de imagem para seus serviços (ex: `logo: "assets/tools/meu_servico_logo.png"`), coloque o arquivo de imagem correspondente dentro do diretório `config/homer/assets/tools/` no seu host. O caminho no `config.yml` é relativo ao diretório `assets` interno do Homer.
*   **`connectivityCheck: true`:** É recomendado, especialmente para quando o Authelia for implementado, pois ele pode ajudar a lidar com redirecionamentos de autenticação.

## 2. Configuração no `docker-compose.yml`

Adicione o serviço `homer` ao seu arquivo `docker-compose.yml`:

```yaml
services:
  # ... outros serviços como postgres, caddy, n8n ...

  homer:
    image: b4bz/homer:latest
    container_name: homer
    volumes:
      - ./config/homer:/www/assets # Mapeia o diretório de configuração do host
    ports:
      - "8080:8080" # Opcional se acessado apenas via Caddy, mas útil para setup/debug
    # IMPORTANTE: Defina o UID e GID para corresponder ao proprietário
    # do diretório ./config/homer no host.
    # Geralmente 1000:1000 para o usuário padrão 'ubuntu'. Verifique com 'id ubuntu'.
    user: "1000:1000"
    environment:
      - INIT_ASSETS=0 # Definido como 0 pois já estamos fornecendo config.yml
      # - PORT=8080 # Porta interna do Homer (padrão é 8080)
      # - IPV6_DISABLE=0 # Padrão, descomente e mude para 1 se precisar desabilitar IPv6
    restart: unless-stopped
    networks:
      - app-network
```

**Principais Pontos:**
*   **`volumes:`** Mapeia `./config/homer` do host para `/www/assets` no container.
*   **`user: "1000:1000"`:** **ESSENCIAL.** Ajuste o `1000:1000` para o UID:GID do usuário proprietário do diretório `./config/homer` no seu host para evitar problemas de permissão.
*   **`environment.INIT_ASSETS=0`:** Como estamos fornecendo nosso próprio `config.yml`, definimos para `0` para evitar que o Homer tente criar um arquivo de exemplo. Se você preferir que o Homer crie um exemplo inicial, remova/comente esta linha e garanta que `./config/homer` esteja vazio e gravável pelo container na primeira execução.
*   **`ports:`** A porta `8080` do container é exposta. Se você não precisar de acesso direto (sem Caddy), pode remover a seção `ports`.

## 3. Configuração do Caddy (Proxy Reverso)

Modifique seu `config/Caddyfile` para adicionar ou ajustar a entrada para o domínio raiz, que servirá o Homer.

```caddy
{
    email ${CADDY_EMAIL} # Seu email para certificados SSL (obtido do .env)
    # ... outras configurações globais ...
}

# Configuração para o Homer (Dashboard Principal)
galvani4987.duckdns.org {
    reverse_proxy homer:8080
    # A autenticação via Authelia será adicionada posteriormente (Fase 3.B)
    # forward_auth http://authelia:9091 {
    #   uri /authelia
    #   copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    # }
}

# ... outras configurações de serviços como n8n.galvani4987.duckdns.org ...
```

**Importante:**
*   Esta configuração assume que Homer será servido no domínio raiz (`galvani4987.duckdns.org`).
*   O `reverse_proxy homer:8080` direciona o tráfego para o container do Homer.
*   A seção `forward_auth` para Authelia está comentada e será configurada em uma fase posterior do roadmap.

## 4. Implantação

1.  **Certifique-se de que o DNS está configurado:** O domínio `galvani4987.duckdns.org` deve estar apontando para o IP do seu servidor.
2.  **Inicie/Atualize os serviços:**
    No diretório raiz do projeto, execute:
    ```bash
    docker compose up -d homer
    ```
    Se você modificou o `config/Caddyfile`, recarregue a configuração do Caddy:
    ```bash
    docker compose exec -w /etc/caddy caddy caddy reload
    # Ou reinicie o Caddy se preferir: docker compose restart caddy
    ```

## 5. Verificação

1.  **Logs do Docker:** Verifique os logs do Homer para quaisquer erros:
    ```bash
    docker compose logs homer
    ```
    Você deve ver mensagens indicando que o servidor web interno do Homer (lighttpd) iniciou na porta 8080.
2.  **Acesso via Navegador:** Abra `https://galvani4987.duckdns.org` no seu navegador.
    *   Você deverá ver seu painel Homer customizado conforme definido no `config/homer/config.yml`.
    *   Verifique se os links e ícones aparecem corretamente.
3.  **Permissões:** Se o Homer não carregar ou mostrar erros, verifique as permissões do diretório `./config/homer` no host e o UID/GID configurado no `docker-compose.yml`.

## 6. Próximos Passos no Roadmap

Com o Homer implantado e verificado:
*   Marque as etapas "2.B.1 Pesquisa", "2.B.2 Configuração", "2.B.3 Implantação" e "2.B.4 Verificação" como `[✅]` no `ROADMAP.md`.
*   Prossiga para a configuração do Redis (Fase 3.A) ou outros serviços conforme o roadmap.

Este tutorial cobriu a configuração e implantação do Homer. Para mais opções de personalização (temas, mais tipos de links, etc.), consulte a [documentação oficial do Homer no GitHub](https://github.com/bastienwirtz/homer).
```
