# Tutorial: Configurando o Redis

Este tutorial guia você pela configuração e implantação do Redis, um banco de dados em memória ultrarrápido. Neste projeto, o Redis será utilizado principalmente para o gerenciamento de sessões do Authelia.

## Pré-requisitos

*   Nenhum serviço específico precisa estar rodando antes do Redis, mas ele é uma dependência para o Authelia (Fase 3.B).

## 1. Variáveis de Ambiente para Redis

Adicione a seguinte variável ao seu arquivo `.env` na raiz do projeto. Esta senha será usada para proteger seu servidor Redis.

```env
# Senha para o Redis
# Escolha uma senha forte e segura.
REDIS_PASSWORD=sua_senha_forte_para_o_redis_aqui
```

## 2. Configuração no `docker-compose.yml`

Adicione o serviço `redis` ao seu arquivo `docker-compose.yml`:

```yaml
services:
  # ... outros serviços como postgres, caddy, n8n, homer ...

  redis:
    image: redis:alpine # Imagem oficial do Redis, versão Alpine para menor tamanho
    container_name: redis
    restart: unless-stopped
    command:
      - redis-server
      - --save 60 1             # Persistência RDB: salva o DB se houver 1+ mudança em 60s
      - --loglevel warning        # Nível de log
      - --requirepass ${REDIS_PASSWORD} # Define a senha para conexão
    volumes:
      - redis_data:/data        # Mapeia o volume para persistência dos dados do Redis
    networks:
      - app-network
    # Nenhuma porta precisa ser exposta ao host, pois o Redis será acessado
    # apenas pelo Authelia através da rede interna do Docker ('app-network').
```

**Principais Pontos da Configuração:**
*   **`image: redis:alpine`**: Utiliza a imagem oficial do Redis com a tag `alpine` para um tamanho reduzido.
*   **`command:`**:
    *   `redis-server`: Inicia o servidor Redis.
    *   `--save 60 1`: Configura a persistência RDB. O Redis salvará o dataset no disco se pelo menos 1 chave tiver mudado em 60 segundos. Isso oferece um bom equilíbrio entre desempenho e durabilidade dos dados para o caso de uso de sessões do Authelia.
    *   `--loglevel warning`: Define o nível de log para reduzir a verbosidade.
    *   `--requirepass ${REDIS_PASSWORD}`: Protege o servidor Redis com a senha definida no arquivo `.env`.
*   **`volumes: - redis_data:/data`**: Essencial para a persistência dos dados do Redis. Garante que os dados (incluindo sessões, se o Redis estiver configurado para persisti-las ativamente) não sejam perdidos se o container for reiniciado.
*   **`networks: - app-network`**: Conecta o Redis à rede interna definida no projeto, permitindo que outros containers (como o Authelia) o acessem pelo nome do serviço (`redis`).
*   **Portas:** Nenhuma porta é exposta ao host, o que é uma boa prática de segurança, já que apenas serviços internos precisam acessar o Redis.

Não se esqueça de adicionar `redis_data:` à seção global de `volumes` no final do seu `docker-compose.yml`, se ainda não estiver lá por outros serviços:
```yaml
volumes:
  # ... outros volumes ...
  redis_data:
```

## 3. Implantação

1.  **Inicie o serviço Redis:**
    No diretório raiz do projeto (onde está o `docker-compose.yml`), execute:
    ```bash
    docker compose up -d redis
    ```

## 4. Verificação

1.  **Logs do Docker:** Verifique os logs do Redis para confirmar que ele iniciou corretamente e a senha está ativa:
    ```bash
    docker compose logs redis
    ```
    Procure por mensagens como:
    *   `Ready to accept connections`
    *   A ausência de erros óbvios.
    *   Se o loglevel for `verbose` ou `debug` (não é o caso com `warning`), você poderia ver menções à diretiva `requirepass`.
2.  **Teste de Conexão (Opcional, de outro container):**
    Se você quiser testar a conexão e a autenticação, você pode fazer isso de dentro de outro container que esteja na mesma rede `app-network` e tenha `redis-cli` instalado (por exemplo, temporariamente adicionar `redis-cli` ao container do Authelia ou a um container de debug).
    Comandos de exemplo dentro de um container com `redis-cli`:
    ```bash
    # Conectar ao redis (substitua 'redis' pelo nome do host/serviço se necessário)
    redis-cli -h redis

    # Tentar um comando sem autenticar (deve falhar)
    # > PING
    # (error) NOAUTH Authentication required.

    # Autenticar (substitua 'sua_senha_forte_para_o_redis_aqui' pela senha real do .env)
    # > AUTH sua_senha_forte_para_o_redis_aqui
    # OK

    # Tentar o comando novamente
    # > PING
    # PONG

    # Sair
    # > QUIT
    ```
    Este passo é opcional, pois a principal verificação será quando o Authelia se conectar a ele.

## 5. Próximos Passos no Roadmap

Com o Redis implantado e verificado:
*   Marque as etapas "3.A.1 Pesquisa", "3.A.2 Configuração", "3.A.3 Implantação" e "3.A.4 Verificação" como `[✅]` no `ROADMAP.md`.
*   O Redis está agora pronto para ser usado pelo Authelia (Fase 3.B). A configuração do Authelia para usar este serviço Redis será detalhada no tutorial do Authelia.

Este tutorial cobriu a configuração básica e segura do Redis para uso com Authelia neste projeto. Para configurações mais avançadas do Redis, consulte a [documentação oficial do Redis](https://redis.io/docs/) e a [documentação da imagem Docker do Redis](https://hub.docker.com/_/redis).
```
