# stage 1: pull and build internal logic package
FROM node:24-alpine AS logic-builder
RUN apk add --no-cache git
WORKDIR /app/vote-internals
ARG CACHEBUST=1
RUN git clone https://github.com/SeraphInteractive/MCS-internal-logic.git .
RUN npm ci
RUN npm run build

# stage 2: pull and build adonisjs api
FROM node:24-alpine AS api-builder
RUN apk add --no-cache git
WORKDIR /app/vote-internals
COPY --from=logic-builder /app/vote-internals /app/vote-internals
WORKDIR /app/vote-api
ARG CACHEBUST=1
RUN git clone https://github.com/SeraphInteractive/Platform-API.git .
RUN npm ci
RUN node ace build

# stage 3: lean production runner
FROM node:24-alpine AS runner
WORKDIR /app/vote-api
ENV NODE_ENV=production

# compiled logic dependency stays as sibling so the file reference resolves
COPY --from=logic-builder /app/vote-internals /app/vote-internals
# compiled api output
COPY --from=api-builder /app/vote-api/build ./
RUN npm ci --omit="dev"

# entrypoint handles migrations on boot
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x ./docker-entrypoint.sh

EXPOSE 3333
ENTRYPOINT ["./docker-entrypoint.sh"]
