# MCS-deployment

Docker Compose deployment for the MCS voting system. Clones and builds everything from GitHub during image build, so no local repos needed.

## Services

- `postgres`: PostgreSQL 16 on port 5432 with persistent volume
- `redis`: Redis 7 on port 6379 with persistent volume
- `api`: AdonisJS 6 backend on port 3333, compiled with `@vote-internals/logic`

## Quick Start

```bash
git clone git@github.com:SeraphInteractive/MCS-deployment.git
cd MCS-deployment

# copy environment template and fill in your values
cp .env.example .env

# generate an app key if needed
# node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
# paste into APP_KEY in .env

# start the stack (pulls repos, builds images, starts postgres + redis, runs migrations, boots api)
docker compose up -d --build

# check logs
docker compose logs -f api

# stop the stack
docker compose down
```
