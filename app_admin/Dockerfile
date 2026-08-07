# ---- build ----
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
# Preenchido pelo Railway a partir da variável de serviço de mesmo nome (ver
# railway.json / README) — aponta pro domínio público do serviço backend.
ARG AGENDA360_API_BASE_URL=http://localhost:8000
RUN flutter pub get
RUN flutter build web --release --dart-define=AGENDA360_API_BASE_URL=${AGENDA360_API_BASE_URL}

# ---- serve ----
FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
# nginx:alpine roda envsubst nos templates automaticamente no start,
# substituindo só variáveis de ambiente definidas (não mexe nas variáveis
# nginx como $uri) — é assim que o PORT dinâmico do Railway chega ao nginx.
ENV PORT=8080
EXPOSE 8080
