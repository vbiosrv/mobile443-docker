#!/usr/bin/env bash
set -Eeuo pipefail

IPSET_NAME="allowed_mobile_443"
TMPSET_NAME="${IPSET_NAME}_tmp"
CHAIN_NAME="FILTER_MOBILE_443"

BASE_DIR="/opt/mobile443"
STATE_DIR="/var/lib/mobile443"
ASNS_FILE="${BASE_DIR}/asns.conf"
CACHE_FILE="${STATE_DIR}/prefixes.txt"
LOCK_FILE="${STATE_DIR}/lock"

log() {
    echo "[$(date '+%F %T')] $*"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing command: $1" >&2
        exit 1
    }
}

ensure_deps() {
    need_cmd curl
    need_cmd jq
    need_cmd ipset
    need_cmd iptables
    need_cmd flock
}

ensure_ipsets() {
    ipset create "$IPSET_NAME" hash:net family inet hashsize 65536 maxelem 524288 -exist 2>/dev/null || {
        log "Failed to create ipset $IPSET_NAME"
        return 1
    }
    ipset create "$TMPSET_NAME" hash:net family inet hashsize 65536 maxelem 524288 -exist 2>/dev/null || {
        log "Failed to create ipset $TMPSET_NAME"
        return 1
    }
}

count_lines() {
    local file="$1"
    [[ -f "$file" ]] || { echo 0; return; }
    wc -l < "$file" | tr -d ' '
}

load_prefixes_into_tmpset() {
    local file="$1"
    ipset flush "$TMPSET_NAME" 2>/dev/null || true

    while IFS= read -r prefix; do
        [[ -n "$prefix" ]] || continue
        ipset add "$TMPSET_NAME" "$prefix" -exist 2>/dev/null || log "Failed to add $prefix"
    done < "$file"
}

swap_sets() {
    ipset swap "$TMPSET_NAME" "$IPSET_NAME" 2>/dev/null || {
        log "Failed to swap ipsets"
        return 1
    }
    ipset flush "$TMPSET_NAME" 2>/dev/null || true
}

prepare_chain() {
    # Создание цепочки если не существует
    iptables -N "$CHAIN_NAME" 2>/dev/null || true
    iptables -F "$CHAIN_NAME"

    iptables -A "$CHAIN_NAME" -m set --match-set "$IPSET_NAME" src -j ACCEPT
    iptables -A "$CHAIN_NAME" -j DROP
}

delete_jump_if_exists() {
    local chain="$1"
    local proto="$2"
    while iptables -C "$chain" -p "$proto" --dport 443 -j "$CHAIN_NAME" 2>/dev/null; do
        iptables -D "$chain" -p "$proto" --dport 443 -j "$CHAIN_NAME"
    done
}

attach_chain() {
    for chain in INPUT FORWARD; do
        delete_jump_if_exists "$chain" tcp
        delete_jump_if_exists "$chain" udp
        iptables -I "$chain" 1 -p tcp --dport 443 -j "$CHAIN_NAME" 2>/dev/null || true
        iptables -I "$chain" 1 -p udp --dport 443 -j "$CHAIN_NAME" 2>/dev/null || true
    done

    if iptables -nL DOCKER-USER >/dev/null 2>&1; then
        delete_jump_if_exists DOCKER-USER tcp
        delete_jump_if_exists DOCKER-USER udp
        iptables -I DOCKER-USER 1 -p tcp --dport 443 -j "$CHAIN_NAME" 2>/dev/null || true
        iptables -I DOCKER-USER 1 -p udp --dport 443 -j "$CHAIN_NAME" 2>/dev/null || true
    fi
}

apply_rules() {
    ensure_ipsets
    prepare_chain
    attach_chain
}