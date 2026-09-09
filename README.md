# MCS-deployment

Deployment setup for the voting system (PostgreSQL, Redis, and API).

## How to run

1. Copy env file:
cp .env.example .env

2. Start the stack:
docker compose up -d --build

3. View logs:
docker compose logs -f api

4. Stop the stack:
docker compose down

## Endpoints

- Health check: GET http://localhost:3333/
- API routes: http://localhost:3333/api/v1/
