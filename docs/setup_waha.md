# Tutorial: Configurando o WAHA (WhatsApp HTTP API)

Este tutorial guia você pela configuração e implantação do WAHA (WhatsApp HTTP API), permitindo que você envie e receba mensagens do WhatsApp através de uma API REST. Neste projeto, WAHA será integrado com n8n.

## Pré-requisitos

1.  **Serviços Essenciais Rodando:**
    *   `caddy`: Configurado e rodando (Fase 1.B).
    *   (Opcional, mas recomendado) `n8n`: Configurado e rodando (Fase 2.A), se você planeja integrar webhooks do WAHA com n8n imediatamente.
2.  **Diretório de Configuração:** Crie os diretórios no host para armazenar os dados persistentes do WAHA:
    ```bash
    mkdir -p config/waha/sessions
    mkdir -p config/waha/media
    ```
3.  **Número de WhatsApp:** Você precisará de um número de WhatsApp ativo em um smartphone para escanear o QR code e vincular à instância do WAHA.

## 1. Variáveis de Ambiente para WAHA

Adicione as seguintes variáveis ao seu arquivo `.env` na raiz do projeto:

```env
# --- Configurações do WAHA (WhatsApp HTTP API) ---

# Chave de API para proteger o acesso à API do WAHA.
# Gere uma string aleatória longa e segura (ex: openssl rand -hex 32)
WHATSAPP_API_KEY=sua_api_key_segura_para_waha_aqui

# URL base pública do WAHA (usada para construir URLs de mídia em webhooks, etc.)
WAHA_BASE_URL=https://waha.galvani4987.duckdns.org

# URL do Webhook para onde o WAHA enviará eventos (ex: novas mensagens).
# Substitua pela URL do seu webhook do n8n quando configurado.
# Exemplo: WAHA_WEBHOOK_URL=https://n8n.galvani4987.duckdns.org/webhook/waha-events
WHATSAPP_HOOK_URL=https://n8n.galvani4987.duckdns.org/webhook-waha # Altere para sua URL real do n8n
# Eventos para enviar ao webhook (message,message.any,state.change são um bom começo)
WHATSAPP_HOOK_EVENTS=message,message.any,state.change

# Configurações de Debug e Log
WAHA_DEBUG_MODE=false # Define como true para logs mais detalhados durante o setup inicial, se necessário
WAHA_LOG_LEVEL=info   # Níveis: error, warn, info, debug, trace

# Timezone para o container do WAHA
TZ=America/Sao_Paulo # Ou sua timezone preferida
```

**Notas sobre Variáveis:**
*   **`WHATSAPP_API_KEY`**: Essencial para proteger sua API WAHA. Qualquer requisição à API precisará incluir esta chave no header `X-Api-Key`.
*   **`WAHA_BASE_URL`**: Deve ser a URL HTTPS pública pela qual o WAHA será acessado através do Caddy.
*   **`WHATSAPP_HOOK_URL`**: Este é o endpoint para onde o WAHA enviará notificações de eventos (como novas mensagens). Você precisará configurar um fluxo de trabalho no n8n (ou outro serviço) que escute nesta URL.
*   **`WHATSAPP_HOOK_EVENTS`**: Define quais tipos de eventos acionam o webhook. Consulte a documentação do WAHA para todos os eventos disponíveis.

## 2. Configuração no `docker-compose.yml`

Adicione o serviço `waha` ao seu arquivo `docker-compose.yml`:

```yaml
services:
  # ... outros serviços ...

  waha:
    image: devlikeapro/waha:latest # Imagem oficial do WAHA Core
    container_name: waha
    restart: unless-stopped
    ports:
      # Exponha a porta 3000 APENAS se precisar escanear o QR code diretamente
      # pelo navegador no host. Após o setup, pode ser removida se o acesso
      # for apenas via API/Caddy.
      - "127.0.0.1:3000:3000" # Acesso local para setup inicial
    volumes:
      - ./config/waha/sessions:/app/.sessions # Persistência das sessões do WhatsApp
      - ./config/waha/media:/app/.media       # Persistência de arquivos de mídia
    env_file:
      - .env # Carrega as variáveis do arquivo .env
    networks:
      - app-network
    logging: # Configuração de log recomendada pela WAHA
      driver: 'json-file'
      options:
        max-size: '100m'
        max-file: '10'
    # depends_on: # WAHA não tem dependências diretas para iniciar, mas funcionalmente depende do n8n para webhooks.
      # - n8n # Se n8n estiver no mesmo compose e você quiser garantir a ordem.
```

**Principais Pontos:**
*   **`image: devlikeapro/waha:latest`**: Usa a imagem WAHA Core. A documentação menciona que esta usa o motor WEBJS (baseado em Chromium) por padrão.
*   **`ports: - "127.0.0.1:3000:3000"`**: Mapeia a porta 3000 do container para a porta 3000 do host, mas apenas para acesso local (`127.0.0.1`). Isso é útil para acessar a interface Swagger/Dashboard do WAHA diretamente no navegador do host para escanear o QR code inicial. Após o setup, se você não precisar mais de acesso direto, pode remover esta seção de portas, pois o Caddy fará o proxy.
*   **`volumes:`**:
    *   `./config/waha/sessions:/app/.sessions`: **CRUCIAL** para persistir os dados da sessão do WhatsApp após escanear o QR code. Sem isso, você precisará escanear novamente toda vez que o container reiniciar.
    *   `./config/waha/media:/app/.media`: Para armazenar arquivos de mídia trocados.
*   **`env_file: - .env`**: Garante que as variáveis definidas no seu arquivo `.env` sejam carregadas.
*   **`logging:`**: Configuração padrão de logging do WAHA para Docker.

## 3. Configuração do Caddy (Proxy Reverso)

Adicione a seguinte configuração ao seu `config/Caddyfile` para expor o WAHA através do Caddy:

```caddy
# --- WAHA (WhatsApp HTTP API) ---
waha.galvani4987.duckdns.org {
    reverse_proxy waha:3000
}
```

**Explicação:**
*   As requisições para `waha.galvani4987.duckdns.org` são encaminhadas para o serviço `waha` na porta `3000`.
*   **Importante - API Key:** A API do WAHA deve ser protegida pela `WHATSAPP_API_KEY` definida nas variáveis de ambiente. Esta chave é necessária no header `X-Api-Key` de cada requisição à API do WAHA.

## 4. Implantação e Configuração Inicial

1.  **Verifique o `.env`:** Certifique-se de que as variáveis `WHATSAPP_API_KEY`, `WAHA_BASE_URL`, e `WHATSAPP_HOOK_URL` (e outras) estão corretamente definidas no seu arquivo `.env`.
2.  **Inicie/Atualize os Serviços:**
    No diretório raiz do projeto:
    ```bash
    docker compose up -d --remove-orphans waha
    ```
    Se você alterou o `config/Caddyfile`, recarregue a configuração do Caddy:
    ```bash
    docker compose exec -w /etc/caddy caddy caddy reload
    ```
3.  **Acesse a Interface Swagger do WAHA (para QR Code):**
    *   Abra `http://localhost:3000/swagger` no navegador do seu servidor VPS (ou use um túnel SSH se estiver acessando remotamente e não quiser expor a porta 3000 publicamente, mesmo que apenas no localhost do servidor).
    *   **Autenticação da API:** Para usar os endpoints da API (incluindo os da Swagger UI), você precisará fornecer a `WHATSAPP_API_KEY` que você definiu. Geralmente, há um botão "Authorize" ou um campo para inserir a chave (como um header `X-Api-Key`).
4.  **Inicie uma Nova Sessão e Escaneie o QR Code:**
    *   Na Swagger UI, encontre o endpoint `POST /api/sessions/start`.
    *   Clique em "Try it out".
    *   No corpo da requisição, use um nome simples para a sessão, por exemplo:
        ```json
        {
          "name": "default"
        }
        ```
    *   Execute a requisição.
    *   Em seguida, encontre o endpoint `GET /api/sessions/{sessionName}/auth/qr` (ou um endpoint similar para obter o QR code, como `GET /api/screenshot` que foi mencionado na documentação do GitHub - verifique a Swagger UI para o endpoint correto). Substitua `{sessionName}` por `default`.
    *   Execute-o. A resposta deve conter o QR code (geralmente como uma imagem base64 ou um link para ela). Se a Swagger UI não renderizar a imagem diretamente, você pode precisar usar `GET /api/screenshot?session=default` em uma nova aba do navegador (ainda em `http://localhost:3000`).
    *   Escaneie o QR code com o aplicativo WhatsApp no seu celular (Vincular um novo aparelho).
5.  **Verifique o Status da Sessão:**
    *   Após escanear, use o endpoint `GET /api/sessions/{sessionName}` (substitua `{sessionName}` por `default`) para verificar o status. Ele deve mudar para `AUTHENTICATED` ou similar.
    *   Você também pode verificar os logs do WAHA: `docker compose logs waha`.

## 5. Verificação

1.  **Logs do Docker:**
    ```bash
    docker compose logs waha
    ```
    Procure por mensagens indicando que a sessão foi autenticada e que está pronto para receber/enviar mensagens.
2.  **Teste de Envio de Mensagem (via API):**
    *   Use a Swagger UI (`http://localhost:3000/swagger`) ou `curl` para enviar uma mensagem de teste para o seu próprio número de WhatsApp.
    *   Endpoint: `POST /api/sendText`
    *   Corpo da Requisição:
        ```json
        {
          "chatId": "SEU_NUMERO_WHATSAPP@c.us", // Ex: 5511999998888@c.us
          "text": "Olá do WAHA!",
          "session": "default"
        }
        ```
    *   Lembre-se de incluir o header `X-Api-Key` com sua `WHATSAPP_API_KEY`.
3.  **Teste de Webhook (com n8n):**
    *   Se você configurou `WHATSAPP_HOOK_URL` para um webhook do n8n, envie uma mensagem para o número do WhatsApp vinculado ao WAHA.
    *   Verifique se o n8n recebe o evento.

## 6. Próximos Passos no Roadmap

Com o WAHA implantado e verificado:
*   Marque as etapas "3.C.1 Pesquisa", "3.C.2 Configuração", "3.C.3 Implantação" e "3.C.4 Verificação" como `[✅]` no `ROADMAP.md`.
*   Agora você pode usar a API do WAHA para construir integrações ou conectar com ferramentas como o n8n.
    *   **Segurança Adicional (Opcional):** Considere remover ou comentar o mapeamento de porta `"127.0.0.1:3000:3000"` na seção `ports` do serviço `waha` no seu `docker-compose.yml` se o acesso direto à interface do WAHA (Swagger/Dashboard) não for mais necessário e toda a interação futura ocorrerá através da API (protegida pelo Caddy e pela chave de API) ou webhooks.

Este tutorial cobriu a configuração essencial do WAHA. Explore a [documentação oficial do WAHA](https://waha.devlike.pro/docs/overview) para mais funcionalidades e configurações avançadas. Lembre-se da importância de usar o WhatsApp de forma responsável para evitar bloqueios.
```
