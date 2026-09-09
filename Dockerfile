# stage 1: build internal logic package
FROM node:22-alpine AS logic-builder
WORKDIR /app/vote-internals
COPY vote-internals/package*.json ./
RUN npm ci
COPY vote-internals/ ./
RUN npm run build

# stage 2: build adonisjs api
FROM node:22-alpine AS api-builder
WORKDIR /app/vote-api
COPY --from=logic-builder /app/vote-internals /app/vote-internals
COPY vote-api/package*.json ./
RUN npm ci
COPY vote-api/ ./
RUN node ace build

# stage 3: lean production runner
FROM node:22-alpine AS runner
WORKDIR /app/api
ENV NODE_ENV=production

# copy built logic dependency as sibling
COPY --from=logic-builder /app/vote-internals /app/vote-internals
# copy built api output
COPY --from=api-builder /app/vote-api/build ./
RUN npm ci --omit="dev"

# copy entrypoint script for auto migrations
COPY MCS-deployment/docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x ./docker-entrypoint.sh

EXPOSE 3333
ENTRYPOINT ["./docker-entrypoint.sh"]
