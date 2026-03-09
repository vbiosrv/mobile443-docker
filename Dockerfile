FROM alpine:latest

LABEL maintainer="mobile443" \
      description="Mobile operator filter for port 443 using ipset/iptables"

# Установка зависимостей
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    ipset \
    iptables \
    ip6tables \
    util-linux \
    tini \
    && rm -rf /var/cache/apk/*

# Создание структуры директорий
RUN mkdir -p /opt/mobile443 /var/lib/mobile443

# Копирование скриптов
COPY asns.conf /opt/mobile443/
COPY mobile443-common.sh /usr/local/sbin/
COPY mobile443-update.sh /usr/local/sbin/
COPY mobile443-apply-cache.sh /usr/local/sbin/
COPY entrypoint.sh /

# Права на выполнение
RUN chmod +x /usr/local/sbin/*.sh /entrypoint.sh

# Использование tini для корректной обработки сигналов
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

# Команда по умолчанию
CMD ["apply"]