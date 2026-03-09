#!/usr/bin/env bash
set -Eeuo pipefail
source /usr/local/sbin/mobile443-common.sh

mkdir -p "$STATE_DIR"

# Обработка флага --cleanup
if [[ "${1:-}" == "--cleanup" ]]; then
    log "Cleaning up iptables rules..."
    for chain in INPUT FORWARD DOCKER-USER; do
        for proto in tcp udp; do
            delete_jump_if_exists "$chain" "$proto"
        done
    done
    iptables -F "$CHAIN_NAME" 2>/dev/null || true
    iptables -X "$CHAIN_NAME" 2>/dev/null || true
    exit 0
fi

exec 9>"$LOCK_FILE"
flock -n 9 || {
    log "Another mobile443 job is already running"
    exit 0
}

ensure_deps
ensure_ipsets

if [[ ! -s "$CACHE_FILE" ]]; then
    log "Cache file not found or empty: $CACHE_FILE"
    log "Creating empty ipset (all traffic will be blocked)"
    ipset flush "$IPSET_NAME" 2>/dev/null || true
    apply_rules
    exit 0
fi

log "Loading cached prefixes from $CACHE_FILE"
load_prefixes_into_tmpset "$CACHE_FILE"
swap_sets
apply_rules
log "Cache applied"