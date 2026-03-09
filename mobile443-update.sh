#!/usr/bin/env bash
set -Eeuo pipefail
source /usr/local/sbin/mobile443-common.sh

TMP_RAW="$(mktemp)"
TMP_CLEAN="$(mktemp)"
trap 'rm -f "$TMP_RAW" "$TMP_CLEAN"' EXIT

mkdir -p "$STATE_DIR"

exec 9>"$LOCK_FILE"
flock -n 9 || {
    log "Another mobile443 job is already running"
    exit 0
}

ensure_deps
ensure_ipsets

[[ -f "$ASNS_FILE" ]] || { echo "ASN file not found: $ASNS_FILE" >&2; exit 1; }

log "Fetching announced prefixes from RIPEstat"

while IFS= read -r asn; do
    [[ -z "$asn" || "$asn" =~ ^# ]] && continue
    log "Fetching AS${asn}"
    curl -fsS --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 30 \
        "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${asn}" \
        | jq -r '.data.prefixes[]?.prefix // empty' >> "$TMP_RAW" || {
            log "Failed to fetch AS${asn}"
            continue
        }
    # Небольшая задержка чтобы не нагружать API
    sleep 0.5
done < "$ASNS_FILE"

sort -Vu "$TMP_RAW" \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$' \
    > "$TMP_CLEAN" || true

NEW_COUNT="$(count_lines "$TMP_CLEAN")"
OLD_COUNT="$(count_lines "$CACHE_FILE")"

log "Collected prefixes: new=${NEW_COUNT}, old=${OLD_COUNT}"

if [[ "$NEW_COUNT" -lt 500 ]]; then
    log "Refusing update: too few prefixes (${NEW_COUNT})"
    exit 1
fi

if [[ "$OLD_COUNT" -gt 0 ]]; then
    MIN_SAFE=$(( OLD_COUNT * 70 / 100 ))
    if [[ "$NEW_COUNT" -lt "$MIN_SAFE" ]]; then
        log "Refusing update: new prefix count dropped too much (need >= ${MIN_SAFE})"
        exit 1
    fi
fi

load_prefixes_into_tmpset "$TMP_CLEAN"
swap_sets
cp "$TMP_CLEAN" "$CACHE_FILE"

apply_rules

log "Update complete"