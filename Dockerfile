# Etapa de construcción (builder)
FROM node:20-alpine AS builder

RUN apk update && \
    apk add git ffmpeg wget curl bash openssl

LABEL version="2.2.2" \
      description="Api to control whatsapp features through http requests." \
      maintainer="Davidson Gomes" \
      git="https://github.com/DavidsonGomes" \
      contact="contato@atendai.com"

# Usamos /app para construir la aplicación
WORKDIR /app

# Copiamos los archivos base
COPY ./package.json ./tsconfig.json ./

# Instalamos dependencias
RUN npm install

# Copiamos el resto del código y archivos necesarios
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./
COPY ./tsup.config.ts ./
COPY ./Docker ./Docker

# Aseguramos que los scripts sean ejecutables y en formato Unix
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# Ejecutamos el script para generar la base de datos (migraciones, cliente Prisma, etc.)
RUN ./Docker/scripts/generate_database.sh
RUN npm run build

# Etapa final
FROM node:20-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

ENV TZ=America/Guayaquil

# Directorio de aplicación
WORKDIR /app

# Copiamos los artefactos del builder
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/manager ./manager
COPY --from=builder /app/public ./public
COPY --from=builder /app/.env ./.env
COPY --from=builder /app/Docker ./Docker
COPY --from=builder /app/runWithProvider.js ./runWithProvider.js
COPY --from=builder /app/tsup.config.ts ./tsup.config.ts

ENV DOCKER_ENV=true

EXPOSE 8080

# Nota: el script deploy_database.sh se ejecuta antes de iniciar la app.
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
