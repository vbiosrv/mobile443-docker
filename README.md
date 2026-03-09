# 📱 Mobile443 Docker Filter

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/docker-supported-blue" alt="Docker">
  <img src="https://img.shields.io/badge/iptables-✓-brightgreen" alt="iptables">
  <img src="https://img.shields.io/badge/ipset-✓-brightgreen" alt="ipset">
  <img src="https://img.shields.io/docker/pulls/vbiosrv/mobile443-docker?style=flat-square&logo=docker" alt="Docker Pulls">
</p>

<p align="center">
  <b>Фильтрация входящего трафика на порт 443 — только мобильные сети РФ</b><br>
  <i>4G/LTE → разрешено • Wi-Fi / проводной интернет / зарубежные VPN → заблокировано</i>
</p>

---

**Mobile443** — это Docker-контейнер, который автоматически собирает актуальные префиксы мобильных операторов России и разрешает входящие соединения на порт 443 (HTTPS / QUIC / HTTP/2 / gRPC и т.д.) **только** с этих сетей.

Самый популярный сценарий использования — защита Reality / Vision / gRPC / Trojan-Go бэкендов от бана по IP и от подключений с проводного интернета.

---

## ✨ Возможности

- Автоматическое обновление списков префиксов через RIPEstat API
- Использование **ipset** + **iptables** для высокой производительности
- Полная изоляция в Docker (не мусорит на хосте)
- Поддержка **amd64**, **arm64**, **armv7**
- Лёгкая настройка ASN под свои нужды
- Интеграция с Xray / V2Ray / sing-box через cgroup-исключение
- Минимальное потребление ресурсов (~30–60 МБ RAM)

---

## 📋 Содержание

- [Поддерживаемые операторы](#поддерживаемые-операторы)
- [Требования](#требования)
- [Быстрый старт](#быстрый-старт)
- [Установка и запуск](#установка-и-запуск)
- [Конфигурация](#конфигурация)
- [Мониторинг и отладка](#мониторинг-и-отладка)
- [Интеграция с Xray / V2Ray](#интеграция-с-xray--v2ray)
- [Команды управления](#команды-управления)
- [Удаление](#удаление)
- [FAQ](#faq)
- [Лицензия](#лицензия)

---

## Поддерживаемые операторы (актуально на 2025–2026)

| Оператор                  | Основной ASN     | Дополнительные ASN                          | Статус |
|---------------------------|------------------|---------------------------------------------|--------|
| МТС                       | 8359             | —                                           | ✅     |
| Билайн (ВымпелКом)        | 3216             | —                                           | ✅     |
| МегаФон                   | 31133            | + ~30 связанных сетей                       | ✅     |
| Tele2                     | 12958            | 15378, 42437, 48092, 48190, 41330 и др.     | ✅     |
| Ростелеком (мобильный)    | 12389            | —                                           | ✅     |
| Miranda                   | 201776           | —                                           | ✅     |
| СберМобайл                | 206673           | —                                           | ✅     |
| Yandex Mobile / Cloud     | 205638           | —                                           | ✅     |
| Win Mobile (К-телеком)    | 203451           | —                                           | ✅     |
| Волна Мобайл              | 203561           | —                                           | ✅     |

> Список ASN можно легко расширить — см. раздел [Конфигурация](#конфигурация)

---

## Требования

- Linux с поддержкой **ipset** и **iptables** (большинство современных дистрибутивов)
- Docker 20.10+
- Рекомендуется Docker Compose v2
- Запуск с флагами `--privileged` и `--network host`

Проверка поддержки:

```bash
uname -r
lsmod | grep -E 'ip_tables|nfnetlink|ipset|xt_set'

Быстрый старт (самый простой способ)
Bashdocker volume create mobile443-state

docker run -d \
  --name mobile443 \
  --privileged \
  --network host \
  --restart unless-stopped \
  -v mobile443-state:/var/lib/mobile443 \
  vbiosrv/mobile443-docker:latesttemp.sh: line 1: docker: command not found
temp.sh: line 3: docker: command not found

Через 30–120 секунд фильтр уже активен.
Проверка:
Bashdocker logs mobile443
docker exec mobile443 iptables -L FILTER_MOBILE_443 -n -v

Установка и запуск (рекомендуемый способ — docker compose)
Bashmkdir mobile443 && cd mobile443

curl -O https://raw.githubusercontent.com/vbiosrv/mobile443-docker/main/docker-compose.yml
curl -O https://raw.githubusercontent.com/vbiosrv/mobile443-docker/main/asns.conf

# (опционально) отредактируйте asns.conf под себя

docker compose up -d

Конфигурация
Основные переменные окружения
YAMLenvironment:
  - TZ=Europe/Moscow
  - UPDATE_SCHEDULE=0 3 * * *          # каждый день в 03:00
  - LOG_LEVEL=info                     # или debug
  - FORCE_UPDATE_ON_START=false
Добавление своего ASN / оператора
Создайте файл custom-asns.conf:
text8359      # МТС
3216      # Билайн
42437     # Tele2 дополнительный
42466     # ещё один оператор
Подключите в docker-compose.yml:
YAMLvolumes:
  - ./custom-asns.conf:/opt/mobile443/asns.conf:ro
После изменения → перезапуск или
Bashdocker compose restart
# или
docker exec mobile443 /entrypoint.sh update

Мониторинг и отладка
Bash# Правила и счётчики трафика
docker exec mobile443 iptables -L FILTER_MOBILE_443 -n -v

# Сколько префиксов загружено
docker exec mobile443 ipset list allowed_mobile_443 -terse

# Проверка своего IP
curl ifconfig.me
docker exec mobile443 ipset test allowed_mobile_443 ВАШ_IP

# Живые логи
docker logs -f mobile443

Интеграция с Xray / V2Ray / sing-box (обязательно!)
Xray сам генерирует исходящий трафик → может попасть под собственный фильтр.
Решение — cgroup-исключение
Bash# 1. Создаём slice
sudo tee /etc/systemd/system/direct.slice << 'EOF'
[Unit]
Description=Traffic excluded from mobile443 filter
Before=sockets.target
EOF

# 2. Переносим Xray в slice
sudo mkdir -p /etc/systemd/system/xray.service.d
sudo tee /etc/systemd/system/xray.service.d/override.conf << 'EOF'
[Service]
Slice=direct.slice
EOF

sudo systemctl daemon-reload
sudo systemctl restart xray

# 3. Добавляем правило в начало цепочки
docker exec mobile443 iptables -I FILTER_MOBILE_443 1 -m cgroup --path "/direct.slice" -j ACCEPT

Удаление
Bashdocker compose down -v

# Если остались правила на хосте
sudo iptables -F FILTER_MOBILE_443 2>/dev/null
sudo iptables -X FILTER_MOBILE_443 2>/dev/null
sudo ipset destroy allowed_mobile_443 2>/dev/null
sudo ipset destroy allowed_mobile_443_tmp 2>/dev/null

FAQ
Почему блокируется только 443 порт?
Потому что именно он используется для HTTPS / QUIC / Reality / Vision / gRPC. Остальной трафик остаётся открытым.
Мой мобильный интернет не проходит
Проверьте: ipset test allowed_mobile_443 ВАШ_IP
Скорее всего нужен дополнительный ASN оператора.
Работает ли IPv6?
Пока нет — только IPv4. IPv6 в планах.
Как часто обновляются префиксы?
По умолчанию — раз в сутки. Можно настроить чаще.
Можно ли без Docker?
Да — смотрите ветку legacy в этом репозитории.

Лицензия
MIT License
