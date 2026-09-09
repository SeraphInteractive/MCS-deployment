# MCS-deployment

Docker Compose deployment setup for the MCS voting system. Orchestrates PostgreSQL, Redis, and the AdonisJS API with auto-migrations and multi-stage builds.

## Services

- `postgres`: PostgreSQL 16 on port 5432 with persistent volume
- `redis`: Redis 7 on port 6379 with persistent volume
- `api`: AdonisJS 6 backend on port 3333, compiled with `@vote-internals/logic`

## Quick Start

```bash
# copy environment template
cp .env.example .env

# generate an app key if needed
# inside vote-api: node ace generate:key
# then paste into .env

# start the stack (builds images, starts postgres + redis, runs migrations, boots api)
docker compose up -d --build

# check logs
docker compose logs -f api

# stop the stack
docker compose down
```

## Directory Structure Expectation

For builds, sibling directories are expected:
- `../vote-internals` (MCS-internal-logic)
- `../vote-api` (MCS-api)
- `../MCS-deployment` (this repo)
