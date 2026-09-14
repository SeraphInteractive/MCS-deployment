# Platform-Deployment

Production deployment of the platform stack, run by [Dokploy](https://dokploy.com) from
container images published to GitHub Packages.

| Service    | Source                                                                        | Image                                        |
| ---------- | ----------------------------------------------------------------------------- | -------------------------------------------- |
| `api`      | [Platform-API](https://github.com/SeraphInteractive/Platform-API)             | `ghcr.io/seraphinteractive/platform-api`     |
| `migrate`  | same image as `api`; one-shot job that applies migrations before `api` starts | `ghcr.io/seraphinteractive/platform-api`     |
| `bot`      | [Platform-Discord](https://github.com/SeraphInteractive/Platform-Discord)     | `ghcr.io/seraphinteractive/platform-discord` |
| `postgres` | `postgres:16-alpine`                                                          | data in the `postgres_data` volume           |
| `redis`    | `redis:7-alpine`, ephemeral cache (no persistence, LRU eviction)              |                                              |

The API depends on [Platform-Internal-Logic](https://github.com/SeraphInteractive/Platform-Internal-Logic)
as a pinned git dependency; it is compiled into the API image.

## How a change reaches production

```
push to main ──▶ GitHub Actions builds the image ──▶ ghcr.io ──▶ Dokploy redeploys this compose file
 (app repo)      (.github/workflows/docker-publish.yml)             (pull_policy: always)
```

- Every push to `main` in an app repo publishes `latest`, `main` and `sha-<short>` tags; a `vX.Y.Z`
  git tag additionally publishes `X.Y.Z` and `X.Y`. Pull requests only build, they never push.
- Which tag runs is chosen with `PLATFORM_API_TAG` / `PLATFORM_DISCORD_TAG` (default `latest`).
  Pin them to a release or `sha-` tag when you want reproducible rollouts and explicit rollbacks.
- The redeploy is triggered either by the app repos' workflow (see [CI-triggered redeploys](#ci-triggered-redeploys)),
  by Dokploy's auto-deploy when this repo changes, or by clicking **Deploy** in Dokploy.
- Ingress and TLS are Dokploy's Traefik. This file binds no host ports and contains no proxy.

## First deployment

### 1. Publish the images

Push the app repos' `main` once so the workflows publish the images. Then open each package on
GitHub (organisation → **Packages**) and confirm its visibility is **Public**; a freshly created
package may be private. If you prefer private images, add `ghcr.io` under Dokploy → **Settings →
Registry** with a GitHub PAT that has `read:packages`.

### 2. Create the Compose service in Dokploy

1. Project → **Create Service → Compose**.
2. **Provider**: GitHub (via the Dokploy GitHub app) or Git with the public URL
   `https://github.com/SeraphInteractive/Platform-Deployment.git`; branch `main`;
   compose path `./docker-compose.yml`; compose type *Docker Compose* (not *Stack*).
3. **Environment**: paste [`.env.example`](.env.example) and fill it in. Every variable marked
   `(required)` must have a value or the deploy fails immediately with a message naming it.
   Generate secrets with `openssl rand -base64 32` (`APP_KEY`, `DB_PASSWORD`, `REDIS_PASSWORD`).
4. **Domains**: add the API's domain with service `api`, container port `3333`, HTTPS enabled
   with a Let's Encrypt certificate. Use the same URL for `APP_URL`, and register
   `<APP_URL>/api/v1/auth/discord/callback` as a redirect in the Discord developer portal
   (`DISCORD_REDIRECT_URI`).
5. **Deploy**. In the deployment log you should see `migrate` apply the migrations and exit,
   `api` become healthy (`GET /health` returns 200 once Postgres and Redis answer) and `bot`
   log in to Discord. `https://<APP_URL>/health` shows the same report.

### 3. After the first deploy

- **Register the slash commands** (once per command change): open the `bot` container's
  terminal in Dokploy (or `docker exec <bot container> ...` on the server) and run
  `node dist/bot/deploy-commands.js`. Set `DISCORD_GUILD_ID` first if you want instant,
  guild-scoped registration.
- **Give the bot an API token**: while logged in to Discord as a supervisor or admin, open
  `<APP_URL>/api/v1/auth/discord`. After consenting you are redirected to the web app with
  `?token=...` in the URL; put that value in `API_BEARER_TOKEN` and redeploy. The bot starts
  without it, but every API call fails until it is set.

## CI-triggered redeploys

The app repos' workflow can ask Dokploy to redeploy this stack after a successful push to
`main`. It only runs when all three secrets exist in the app repository:

| Secret               | Value                                                                     |
| -------------------- | ------------------------------------------------------------------------- |
| `DOKPLOY_URL`        | Dokploy's base URL, e.g. `https://dokploy.example.com`                    |
| `DOKPLOY_API_KEY`    | Dokploy → Settings → Profile → API/CLI keys                               |
| `DOKPLOY_COMPOSE_ID` | The id in this service's Dokploy URL (`.../services/compose/<composeId>`) |

It calls `POST /api/compose.deploy`, which is the same action as the **Deploy** button. If you
would rather roll out by pinning tags, leave the secrets unset, change the `*_TAG` variables in
Dokploy and click **Deploy**.

## Operations

**Migrations** run on every deploy through the `migrate` service and are a no-op when nothing is
pending. `api` does not start if they fail, so a broken migration never takes the API down;
inspect the `migrate` container's logs, fix, redeploy. To run one by hand:
`docker compose -p <dokploy app name> run --rm migrate node ace migration:status`.

**Backups**: Dokploy's Backups tab can dump the `postgres` service to an S3 destination on a
schedule; enable it before the first real round. Manual dump:
`docker exec <postgres container> pg_dump -U postgres -Fc platform > platform.dump`.

**Logs** are on stdout with rotation (10 MB × 5 per container) and readable in Dokploy or with
`docker logs`. `LOG_LEVEL` controls the API's verbosity.

**Health**: `GET /health` returns 200 with a per-dependency report, 503 when Postgres or Redis
is unreachable. Docker restarts nothing on its own, but Traefik stops routing to an unhealthy
container and the report tells you which dependency to look at.

**Scaling**: run exactly one `api` and one `bot` replica. The API keeps the SSE event bus and
the shot-expiry daemon in memory, so a second replica would miss events and double-run the
daemon.

**Rollback**: set `PLATFORM_API_TAG` / `PLATFORM_DISCORD_TAG` to the previous `sha-` or release
tag and deploy. Migrations are forward-only; roll back the application, not the schema.

**Hardening in the compose file**: no host ports, required secrets with no defaults, non-root
containers with a read-only root filesystem (`tmpfs` on `/tmp`), `no-new-privileges`, bounded
Redis memory, and log rotation. Relax `read_only` for a service if a future version needs to
write outside `/tmp`.

## Local development

`docker-compose.local.yml` builds the images from sibling checkouts and publishes the ports on
`127.0.0.1` instead of pulling from GHCR:

```
Platform-Deployment/   ← this repo
Platform-API/
Platform-Discord/
```

```bash
cp .env.example .env   # fill in the required values
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
```

The API is then on `http://localhost:3333`, Postgres on `localhost:5432`, Redis on
`localhost:6379`. `docker compose ... logs -f api` follows the API.

## Migrating from the previous setup

The old compose file built the images on the server, ran Caddy on ports 80/443 (which would
collide with Dokploy's Traefik) and defaulted the database name to `mcs_voting`. To keep the
data, dump it from the old host and restore into the new `postgres` container, or set
`DB_DATABASE=mcs_voting` if you move the volume as-is.
