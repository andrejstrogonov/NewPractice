#!/bin/sh

# Получаем новый сертификат
certbot certonly --webroot -w /var/www/certbot -d your-domain.com --non-interactive --agree-tos --email your-email@example.com

# Перезагружаем Nginx
nginx -s reload

# Перезапускаем Stunnel (если сертификаты обновились)
pkill -HUP stunnel
