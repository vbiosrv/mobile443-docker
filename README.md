# 📱 Mobile443 Docker Filter

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/docker-supported-blue" alt="Docker">
  <img src="https://img.shields.io/badge/iptables-✓-brightgreen" alt="iptables">
  <img src="https://img.shields.io/badge/ipset-✓-brightgreen" alt="ipset">
</p>

<p align="center">
  <b>🇷🇺 Фильтрация порта 443 для трафика только из мобильных сетей РФ</b><br>
  <i>4G/LTE - ДОСТУП РАЗРЕШЁН | Wi-Fi/Проводной - ДОСТУП ЗАБЛОКИРОВАН</i>
</p>

---

## 📋 Содержание

- [О проекте](#о-проекте)
- [Поддерживаемые операторы](#поддерживаемые-операторы)
- [Требования](#требования)
- [Быстрый старт](#быстрый-старт)
- [Конфигурация](#конфигурация)
- [Мониторинг](#мониторинг)
- [Команды](#команды)
- [Интеграция с Xray](#интеграция-с-xray)
- [Удаление](#удаление)
- [Преимущества Docker версии](#преимущества-docker-версии)
- [FAQ](#faq)
- [Лицензия](#лицензия)

---

## 🎯 О проекте

**Mobile443** — это Docker-контейнер для фильтрации входящего трафика на порт 443 (HTTPS/QUIC) на основе IP-адресов отправителя. 

### 🔍 Принцип работы

1. Собирает префиксы всех мобильных операторов РФ через API RIPEstat
2. Создает ipset `allowed_mobile_443` со списком разрешенных сетей
3. Настраивает iptables для блокировки трафика из всех остальных сетей
📶 Мобильный трафик (4G/LTE) → ✅ РАЗРЕШЁН
📡 Wi-Fi / Проводной → ❌ БЛОКИРОВКА порта 443

text

---

## 📱 Поддерживаемые операторы

| Оператор | ASN | Статус |
|----------|-----|--------|
| **MTS** | `8359` | ✅ |
| **Beeline / VimpelCom** | `3216` | ✅ |
| **MegaFon** | `31133` + 30 связанных ASN | ✅ |
| **Tele2** | `12958`, `15378`, `42437`, `48092`, `48190`, `41330` | ✅ |
| **Rostelecom** | `12389` | ✅ |
| **Miranda** | `201776` | ✅ |
| **Sberbank-Telecom** | `206673` | ✅ |
| **Yandex Cloud** | `205638` | ✅ |
| **Win mobile (К-телеком)** | `203451` | ✅ |
| **Volna mobile (KTK TELECOM)** | `203561` | ✅ |

> 📝 **Примечание:** Список ASN можно легко расширить, отредактировав файл `asns.conf`

---

## 📋 Требования

- **ОС:** Linux (с поддержкой ipset/iptables)
- **Docker:** 20.10+
- **Docker Compose:** 2.0+
- **Ядро:** с поддержкой Netfilter и ipset

### 🔧 Необходимые возможности ядра
```bash
# Проверка поддержки
modprobe xt_set
modprobe xt_cgroup
🚀 Быстрый старт
1. Клонирование репозитория
bash
git clone https://github.com/yourusername/mobile443-docker.git
cd mobile443-docker
2. Запуск контейнера
bash
# Запуск в фоне
docker-compose up -d

# Просмотр логов
docker-compose logs -f
3. Проверка работы
bash
# Проверка правил iptables
docker exec mobile443-filter iptables -L FILTER_MOBILE_443 -n -v

# Просмотр загруженных префиксов
docker exec mobile443-filter ipset list allowed_mobile_443 | head -20
⚙️ Конфигурация
📝 Переменные окружения
В файле docker-compose.yml можно настроить:

yaml
environment:
  - TZ=Europe/Moscow           # Часовой пояс
  - UPDATE_SCHEDULE=0 0 * * *  # CRON расписание обновлений
  - LOG_LEVEL=info              # Уровень логирования (info/debug)
  - FORCE_UPDATE_ON_START=false # Обновлять при старте?
📄 Редактирование списка ASN
Отредактируйте файл asns.conf:

bash
nano asns.conf

# Добавьте нужные ASN
# Например:
21234  # Новый оператор
Примените изменения:

bash
docker-compose restart
# или принудительное обновление
docker exec mobile443-filter /entrypoint.sh update
📊 Мониторинг
📈 Просмотр статистики
bash
# Статистика по цепочке
docker exec mobile443-filter iptables -L FILTER_MOBILE_443 -n -v

# Пример вывода:
Chain FILTER_MOBILE_443 (2 references)
 pkts bytes target     prot opt in     out     source               destination
 123K  75M ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0           match-set allowed_mobile_443 src
 4567 234K DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0
🔍 Просмотр загруженных префиксов
bash
# Все префиксы
docker exec mobile443-filter ipset list allowed_mobile_443

# Только первые 30
docker exec mobile443-filter ipset list allowed_mobile_443 | head -30

# Количество префиксов
docker exec mobile443-filter ipset list allowed_mobile_443 -terse
📋 Логи
bash
# Реальные время логи
docker-compose logs -f --tail 100

# Логи обновлений
docker exec mobile443-filter cat /var/log/mobile443-cron.log
🛠 Команды
🐳 Docker Compose команды
bash
# Запуск
docker-compose up -d

# Остановка
docker-compose stop

# Перезапуск
docker-compose restart

# Просмотр статуса
docker-compose ps

# Логи
docker-compose logs -f
🔧 Внутренние команды контейнера
bash
# Применить кэшированные правила
docker exec mobile443-filter /entrypoint.sh apply

# Обновить префиксы и применить
docker exec mobile443-filter /entrypoint.sh update

# Запустить как демон (по умолчанию)
docker exec mobile443-filter /entrypoint.sh daemon

# Очистить все правила и ipset
docker exec mobile443-filter /entrypoint.sh cleanup
📅 Ручное обновление
bash
# Немедленное обновление
docker exec mobile443-filter /usr/local/sbin/mobile443-update.sh

# Применить кэш
docker exec mobile443-filter /usr/local/sbin/mobile443-apply-cache.sh
🔗 Интеграция с Xray
Для совместной работы с Xray необходимо добавить исключение для трафика самого Xray:

1. Настройка systemd для Xray
bash
# /etc/systemd/system/direct.slice
[Unit]
Description=Срез для трафика, исключенного из фильтрации
Before=sockets.target
2. Добавление в сервис Xray
ini
# /etc/systemd/system/xray.service
[Service]
Slice=direct.slice
3. Добавление правила в iptables
bash
# Исключение трафика Xray из фильтрации
docker exec mobile443-filter iptables -I FILTER_MOBILE_443 1 -m cgroup --path "/direct.slice" -j ACCEPT
🧹 Удаление
Полное удаление
bash
# Остановка и удаление контейнера
docker-compose down -v

# Очистка правил iptables на хосте
iptables -D INPUT -p tcp --dport 443 -j FILTER_MOBILE_443 2>/dev/null || true
iptables -D INPUT -p udp --dport 443 -j FILTER_MOBILE_443 2>/dev/null || true
iptables -F FILTER_MOBILE_443 2>/dev/null || true
iptables -X FILTER_MOBILE_443 2>/dev/null || true

# Очистка ipset
ipset destroy allowed_mobile_443 2>/dev/null || true
ipset destroy allowed_mobile_443_tmp 2>/dev/null || true
🐳 Преимущества Docker версии
Преимущество	Описание
📦 Изоляция	Все зависимости в контейнере, не влияет на хост
🔄 Простота обновления	Пересобрал образ → перезапустил контейнер
🌍 Портативность	Работает на любом Linux с Docker
📊 Мониторинг	Логи через docker logs, стандартные инструменты
⚙️ Управление	Через docker-compose, systemd не требуется
🔒 Безопасность	Ограниченные capabilities, привилегии только для сети
❓ FAQ
❔ Почему блокируется только порт 443?
Порт 443 используется для HTTPS и QUIC трафика — это основной порт для защищенных соединений. Остальной трафик остается без изменений.

❔ Как добавить свой ASN?
Отредактируйте файл asns.conf и добавьте номер ASN в новой строке.

❔ Как часто обновляются префиксы?
По умолчанию — ежедневно в 00:00. Можно изменить в переменной UPDATE_SCHEDULE.

❔ Что делать, если мой трафик блокируется?
Проверьте, что ваш IP попадает в список разрешенных:

bash
curl ifconfig.me
docker exec mobile443-filter ipset test allowed_mobile_443 ВАШ_IP
❔ Работает ли с IPv6?
В текущей версии поддерживается только IPv4. IPv6 планируется в будущих релизах.

❔ Можно ли использовать без Docker?
Да, есть оригинальный bash-скрипт для установки на хост (см. ветку legacy).

📄 Лицензия
MIT License. Подробнее в файле LICENSE.

🤝 Вклад в проект
Fork репозитория

Создайте ветку (git checkout -b feature/amazing)

Commit изменений (git commit -m 'Add amazing feature')

Push в ветку (git push origin feature/amazing)

Откройте Pull Request

📞 Контакты
GitHub: @yourusername

Telegram: @yourusername

Email: your.email@example.com

<p align="center"> <b>Если проект полезен — поставьте ⭐ на GitHub!</b><br> <i>Сделано с ❤️ для 🇷🇺 мобильного интернета</i> </p> ```"# mobile443-docker" 
