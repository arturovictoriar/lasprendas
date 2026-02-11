# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

RUN apk add --no-cache libc6-compat build-base python3
RUN npm install -g @nestjs/cli

COPY package*.json ./
# Usamos npm ci para una instalación limpia y exacta según el lockfile
RUN npm ci

COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache libc6-compat

# Copiamos solo lo necesario para que la imagen sea ligera y limpia
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

EXPOSE 3000

CMD ["npm", "run", "start:prod"]
