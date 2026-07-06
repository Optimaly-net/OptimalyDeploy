#!/usr/bin/env bash
# Map short secret keys to runtime env var names (e.g. ASP.NET __ notation).
# Usage: normalize-secrets.sh <app-config.json>
#
# Configure in app config:
#   "secretMappings": [{ "from": "MISTRAL_API_KEY", "to": "Inference__Mistral__ApiKey" }]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP_CONFIG="${1:?Usage: normalize-secrets.sh <app-config.json>}"
load_app_config "$APP_CONFIG"

secrets_file_rel="$(jq -r '.secretsFile // "secrets/.env"' "$APP_CONFIG")"
SECRETS_FILE="$STACK_PATH/$secrets_file_rel"
[[ -f "$SECRETS_FILE" ]] || exit 0

mapfile -t mappings < <(jq -c '.secretMappings[]? // empty' "$APP_CONFIG")
[[ ${#mappings[@]} -gt 0 ]] || exit 0

log_section "Normalize secrets · $APP_ID"

upsert_from() {
  local source_key="$1"
  local target_key="$2"
  local value
  value="$(grep "^${source_key}=" "$SECRETS_FILE" | head -1 | cut -d= -f2- || true)"
  [[ -n "$value" ]] || return 0
  if grep -q "^${target_key}=" "$SECRETS_FILE"; then
    sed -i "s|^${target_key}=.*|${target_key}=${value}|" "$SECRETS_FILE"
  else
    echo "${target_key}=${value}" >> "$SECRETS_FILE"
  fi
  echo "  $source_key → $target_key"
}

for mapping in "${mappings[@]}"; do
  [[ -z "$mapping" ]] && continue
  from="$(echo "$mapping" | jq -r '.from')"
  to="$(echo "$mapping" | jq -r '.to')"
  upsert_from "$from" "$to"
done
