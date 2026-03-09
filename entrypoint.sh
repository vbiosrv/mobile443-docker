#!/usr/bin/env bash
set -Eeuo pipefail

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка прав
if [[ $EUID -ne 0 ]]; then
    log_error "This container must be run with privileged mode and NET_ADMIN capability"
    exit 1
fi

# Загрузка модулей ядра если доступны
modprobe xt_set 2>/dev/null || log_warn "xt_set module not available, ipset may not work"
modprobe xt_cgroup 2>/dev/null || log_warn "xt_cgroup module not available"

# Функция проверки доступности iptables
check_iptables() {
    if ! iptables -L >/dev/null 2>&1; then
        log_error "iptables is not accessible. Check NET_ADMIN capability."
        return 1
    fi
    return 0
}

# Функция проверки ipset
check_ipset() {
    if ! ipset list >/dev/null 2>&1; then
        log_error "ipset is not accessible. Check NET_ADMIN and SYS_MODULE capabilities."
        return 1
    fi
    return 0
}

# Функция применения правил
apply_rules() {
    log_info "Applying mobile443 rules..."
    if ! /usr/local/sbin/mobile443-apply-cache.sh; then
        log_error "Failed to apply rules"
        return 1
    fi
    log_info "Rules applied successfully"
}

# Функция обновления префиксов
update_prefixes() {
    log_info "Updating mobile443 prefixes..."
    if ! /usr/local/sbin/mobile443-update.sh; then
        log_error "Failed to update prefixes"
        return 1
    fi
    log_info "Prefixes updated successfully"
}

# Функция для запуска периодических обновлений
start_cron() {
    local schedule="${UPDATE_SCHEDULE:-0 0 * * *}"
    log_info "Starting update scheduler with schedule: $schedule"
    
    # Создание crontab
    echo "$schedule /usr/local/sbin/mobile443-update.sh >> /var/log/mobile443-cron.log 2>&1" > /etc/crontabs/root
    
    # Запуск crond в фоне
    crond -b -l 2
    
    # Хвостим лог для docker logs
    touch /var/log/mobile443-cron.log
    tail -f /var/log/mobile443-cron.log &
}

# Функция очистки при выходе
cleanup() {
    log_info "Cleaning up..."
    # Удаление правил iptables
    /usr/local/sbin/mobile443-apply-cache.sh --cleanup 2>/dev/null || true
    # Удаление ipset
    ipset destroy allowed_mobile_443 2>/dev/null || true
    ipset destroy allowed_mobile_443_tmp 2>/dev/null || true
    log_info "Cleanup complete"
}

# Установка обработчика сигналов
trap cleanup SIGTERM SIGINT

# Основная логика
main() {
    local cmd="${1:-apply}"
    
    # Проверка зависимостей
    check_iptables || exit 1
    check_ipset || exit 1
    
    case "$cmd" in
        apply)
            apply_rules
            ;;
        update)
            update_prefixes
            apply_rules
            ;;
        daemon)
            # Применить правила при старте
            if [[ "${FORCE_UPDATE_ON_START:-false}" == "true" ]]; then
                update_prefixes
            else
                # Использовать кэш если есть, иначе обновить
                if [[ -s /var/lib/mobile443/prefixes.txt ]]; then
                    log_info "Using cached prefixes"
                else
                    log_warn "No cache found, updating..."
                    update_prefixes
                fi
            fi
            apply_rules
            
            # Запустить планировщик
            start_cron
            
            # Держим контейнер живым
            log_info "Container running, waiting for signals..."
            while true; do
                sleep infinity &
                wait $!
            done
            ;;
        cleanup)
            cleanup
            ;;
        *)
            echo "Usage: $0 [apply|update|daemon|cleanup]"
            echo "  apply   - Apply cached rules"
            echo "  update  - Update prefixes and apply rules"
            echo "  daemon  - Run as daemon with scheduled updates"
            echo "  cleanup - Remove all rules and ipsets"
            exit 1
            ;;
    esac
}

main "$@"