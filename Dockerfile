# stage 1: pull and build internal logic package
FROM node:22-alpine AS logic-builder
RUN apk add --no-cache git
WORKDIR /app/logic
RUN git clone https://github.com/SeraphInteractive/MCS-internal-logic.git .
RUN npm ci
RUN npm run build

# stage 2: pull and build adonisjs api
FROM node:22-alpine AS api-builder
RUN apk add --no-cache git
WORKDIR /app/logic
COPY --from=logic-builder /app/logic /app/logic
WORKDIR /app/api
RUN git clone https://github.com/SeraphInteractive/MCS-api.git .
RUN npm ci
RUN node ace build

# stage 3: lean production runner
FROM node:22-alpine AS runner
WORKDIR /app/api
ENV NODE_ENV=production

# compiled logic dependency stays as sibling so the file reference resolves
COPY --from=logic-builder /app/logic /app/logic
# compiled api output
COPY --from=api-builder /app/api/build ./
RUN npm ci --omit="dev"

# entrypoint handles migrations on boot
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x ./docker-entrypoint.sh

EXPOSE 3333
ENTRYPOINT ["./docker-entrypoint.sh"]
