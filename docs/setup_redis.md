# Redis Setup Guide (for Authentik)

## Introduction

This Docker Stack includes a Redis instance, containerized as the `authentik-redis` service. Redis is an open-source, in-memory data structure store, often used as a database, cache, and message broker.

In this stack, its primary role is to serve as a **cache and message broker for the Authentik services** (`authentik-server` and `authentik-worker`). It helps improve Authentik's performance and manage background tasks.

This Redis instance is pre-configured as part of the Authentik deployment and generally **requires no direct user intervention** for Authentik to function correctly.

## Service Configuration in `docker-compose.yml`

The `authentik-redis` service is defined in the `docker-compose.yml` file as follows:

```yaml
services:
  # ... other services like caddy, postgres, n8n ...

  authentik-redis:
    image: docker.io/library/redis:alpine # Official Redis image, lightweight Alpine version
    restart: unless-stopped              # Ensures the service restarts automatically
    volumes:
      - authentik_redis:/data            # Mounts a Docker volume for data persistence
    networks:
      - app-network                      # Connects to the shared application network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"] # Command to check service health
      interval: 10s                      # How often to run the health check
      timeout: 5s                        # How long to wait for a response
      retries: 5                         # Number of retries before marking as unhealthy

  authentik-server:
    # ... depends on authentik-redis
    environment:
      AUTHENTIK_REDIS__HOST: authentik-redis # Configures Authentik server to use this Redis
    # ... other authentik-server configurations

  authentik-worker:
    # ... depends on authentik-redis
    environment:
      AUTHENTIK_REDIS__HOST: authentik-redis # Configures Authentik worker to use this Redis
    # ... other authentik-worker configurations

  # ... other services
```

**Key Aspects:**
*   **Image:** Uses the official `redis:alpine` image, which is a common and lightweight choice.
*   **Restart Policy:** Set to `unless-stopped`, meaning Redis will restart automatically with Docker unless manually stopped.
*   **Volume:** The `authentik_redis:/data` named volume is used to persist Redis data. This is important for things like active sessions or queued tasks if Authentik relies on Redis for such features.
*   **Network:** Connected to `app-network`, allowing other services (like `authentik-server` and `authentik-worker`) to communicate with it by its service name (`authentik-redis`).
*   **Healthcheck:** A simple `redis-cli ping` command is used to ensure the Redis server is responsive.

## Environment Variables

For its role supporting Authentik in this stack, `authentik-redis` **does not typically require any user-defined environment variables** in the `.env` file. It operates without a password by default, which is acceptable for an internal service not exposed outside the Docker network. Authentik services are configured to connect to it on the default Redis port without credentials.

## Data Persistence

The Docker volume `authentik_redis:/data` is mapped to the `/data` directory inside the Redis container, which is Redis's default data directory. This setup ensures that any data Redis writes to disk (e.g., snapshots if configured, or data from certain persistence modes) will be stored in the Docker volume and persist even if the `authentik-redis` container is removed or recreated. This is beneficial for Authentik's stability and data retention across updates or restarts.

## Interaction (for Troubleshooting/Curiosity)

While you generally won't need to interact with this Redis instance directly, here's how you can check its status or perform diagnostics (primarily for advanced users or troubleshooting):

*   **Check if Redis is running:**
    ```bash
    docker compose ps authentik-redis
    ```
    (Look for an "Up" status and healthy state)

*   **View Redis logs:**
    ```bash
    docker compose logs authentik-redis
    ```

*   **Access the Redis CLI (Command Line Interface):**
    This allows you to send commands directly to the Redis server.
    1.  Execute the `redis-cli` tool within the running container:
        ```bash
        docker compose exec authentik-redis redis-cli
        ```
    2.  You'll be greeted with the Redis CLI prompt (e.g., `127.0.0.1:6379>`). Here are a few commands you can try:
        *   `PING`
            *   Server should reply with `PONG`. This is a basic connectivity test.
        *   `INFO`
            *   Displays detailed information about the Redis server, including statistics, persistence settings, and client connections.
        *   `DBSIZE`
            *   Shows the number of keys in the current database.
        *   `MONITOR`
            *   Streams all commands processed by the Redis server. (Use `Ctrl+C` to stop). Useful for seeing real-time activity if Authentik is heavily using Redis.
        *   `QUIT`
            *   Exits the `redis-cli`.

    **Note:** Be cautious when running commands that modify data unless you know what you are doing, as this instance is actively used by Authentik.

## Relation to Authentik

The `authentik-server` and `authentik-worker` services are explicitly configured to use this Redis instance. This is typically done via environment variables passed to the Authentik containers, such as:
*   `AUTHENTIK_REDIS__HOST=authentik-redis`
*   `AUTHENTIK_REDIS__PORT=6379` (this is often the default and might not be explicitly set if Authentik assumes it)

Authentik uses Redis for caching various pieces of data to speed up operations, managing user sessions, and coordinating tasks between the server and worker components (e.g., through a task queue like Celery, which often uses Redis as a broker).

## Conclusion

The `authentik-redis` service is a crucial supporting component for the Authentik identity provider within this Docker Stack. It is configured for persistence and health monitoring and operates seamlessly in the background. For most users, it will be a "set it and forget it" service, quietly helping Authentik run efficiently. Direct interaction is generally only needed for advanced troubleshooting.
