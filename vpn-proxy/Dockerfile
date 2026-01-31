# Используем Alpine Linux как легковесную базу
FROM alpine:latest

# Устанавливаем Nginx + JWT‑модуль + Certbot + Stunnel
RUN apk update && apk add --no-cache \
    nginx \
    stunnel \
    certbot \
    python3 \
    py3-pip \
    openssl \
    nginx-mod-http-auth-jwt \
    && pip3 install certbot-nginx

# Копируем конфигурации
COPY nginx.conf /etc/nginx/nginx.conf
COPY stunnel.conf /etc/stunnel/stunnel.conf
COPY certbot-renew.sh /usr/local/bin/certbot-renew.sh

# Директории для сертификатов и Keycloak‑токенов
RUN mkdir -p /etc/letsencrypt/live/your-domain.com \
    && mkdir -p /var/www/certbot \
    && mkdir -p /etc/nginx/keycloak

# Открываем порты
EXPOSE 80 443 1194

# Старт сервисов
CMD ["/bin/sh", "-c", "nginx && stunnel /etc/stunnel/stunnel.conf && tail -f /dev/null"]
