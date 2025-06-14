# Tutorial: Configurando o PostgreSQL

Este tutorial descreve a configuração do PostgreSQL no projeto Docker Stack VPS. O PostgreSQL serve como o sistema de gerenciamento de banco de dados relacional para várias aplicações na pilha, como n8n.

A configuração base do PostgreSQL já está definida nos arquivos `docker-compose.yml` e `.env.example` do projeto, e é estabelecida durante a Fase 1.A do [ROADMAP.md](../../ROADMAP.md).

## 1. Visão Geral da Configuração

O PostgreSQL é configurado para ser robusto e persistente, utilizando a imagem oficial do Docker e variáveis de ambiente para personalização inicial.

*   **Imagem Docker:** `postgres:16-alpine` (uma versão específica do PostgreSQL 16 rodando em Alpine Linux para um tamanho de imagem reduzido).
*   **Persistência de Dados:** Os dados do banco de dados são armazenados em um volume Docker nomeado para garantir que não sejam perdidos quando o container for reiniciado ou recriado.
*   **Acesso:** O PostgreSQL não é exposto publicamente. Ele é acessível apenas por outros containers na mesma rede Docker interna (`app-network`).

## 2. Variáveis de Ambiente (`.env`)

As seguintes variáveis no arquivo `.env` controlam a configuração inicial do PostgreSQL:

```env
# --- Configurações do PostgreSQL ---
POSTGRES_DB=main_db
POSTGRES_USER=admin
POSTGRES_PASSWORD=sua_senha_segura_aqui_para_postgres
```

*   **`POSTGRES_DB`**: Define o nome do banco de dados padrão que será criado quando o PostgreSQL iniciar pela primeira vez com um diretório de dados vazio. No projeto, este é `main_db`.
    *   Serviços como n8n utilizarão este banco de dados.
*   **`POSTGRES_USER`**: Define o nome do superusuário padrão do PostgreSQL. No projeto, este é `admin`.
    *   Este usuário terá controle total sobre o servidor PostgreSQL e será usado pelas aplicações para se conectar ao banco de dados.
*   **`POSTGRES_PASSWORD`**: Define a senha para o `POSTGRES_USER`. **É crucial definir uma senha forte e única aqui.**

Estas variáveis são usadas pelo script de entrada da imagem Docker do PostgreSQL apenas na primeira vez que o container é iniciado com um volume de dados vazio. Se um banco de dados existente for encontrado no volume, estas variáveis são ignoradas.

## 3. Configuração no `docker-compose.yml`

A definição do serviço `postgres` no arquivo `docker-compose.yml` é a seguinte:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    env_file:
      - .env # Carrega as variáveis do arquivo .env
    environment:
      # Garante que as variáveis do .env sejam passadas para o container
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data # Mapeia o volume para persistência
    networks:
      - app-network # Conecta à rede interna definida
    # Nenhuma porta é exposta ao host, garantindo que o DB só seja acessível internamente.
```

**Pontos Chave da Configuração:**
*   **`image: postgres:16-alpine`**: Especifica a imagem Docker a ser usada.
*   **`container_name: postgres`**: Define um nome fixo para o container, facilitando a referência por outros serviços.
*   **`restart: unless-stopped`**: Garante que o container reinicie automaticamente a menos que seja parado manualmente.
*   **`env_file: - .env`**: Carrega todas as variáveis do arquivo `.env`.
*   **`environment:`**: Lista explicitamente as variáveis PostgreSQL para garantir que sejam passadas do `.env` para o ambiente do container. Isso é uma boa prática para clareza.
*   **`volumes: - postgres_data:/var/lib/postgresql/data`**: Este é o ponto mais crítico para a persistência. Ele mapeia um volume nomeado do Docker chamado `postgres_data` para o diretório `/var/lib/postgresql/data` dentro do container, onde o PostgreSQL armazena seus dados.
*   **`networks: - app-network`**: Coloca o container PostgreSQL na rede `app-network`, permitindo que outros serviços (como `n8n`, `authelia`) se conectem a ele usando o nome do serviço `postgres` como hostname.

É necessário também declarar o volume `postgres_data` na seção global `volumes` no final do `docker-compose.yml`:
```yaml
volumes:
  postgres_data:
  # ... outros volumes ...
```

## 4. Uso pelas Aplicações

*   **n8n:** Conecta-se ao PostgreSQL usando as credenciais `POSTGRES_USER` e `POSTGRES_PASSWORD` para o banco de dados `POSTGRES_DB`.

## 5. Verificação (Conforme Roadmap Fase 1.A)

A verificação de que o PostgreSQL está funcionando corretamente envolve:
1.  **Iniciar o serviço:**
    ```bash
    docker compose up -d postgres
    ```
2.  **Verificar status do container:**
    ```bash
    docker compose ps
    ```
    O container `postgres` deve estar listado como "running" ou "healthy" (se um healthcheck estivesse configurado).
3.  **Verificar logs:**
    ```bash
    docker compose logs postgres
    ```
    Procure por mensagens como "database system is ready to accept connections".

## Conclusão

A configuração do PostgreSQL neste projeto é padronizada para uso com Docker, focando em persistência e segurança através do isolamento de rede. Ele serve como uma base de dados confiável para as aplicações que o requerem. Para operações mais avançadas, como backup e restore, ou tuning de performance, consulte a [documentação oficial do PostgreSQL](https://www.postgresql.org/docs/) e da [imagem Docker do PostgreSQL](https://hub.docker.com/_/postgres).
```
