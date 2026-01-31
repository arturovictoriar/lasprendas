FROM node:20-alpine

WORKDIR /app

RUN npm install -g @nestjs/cli
RUN apk add --no-cache libc6-compat build-base python3

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

CMD ["npm", "run", "start:dev"]
