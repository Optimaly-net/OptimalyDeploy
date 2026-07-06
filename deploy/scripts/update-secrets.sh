#!/usr/bin/env bash
# Upsert runtime secrets from environment variables (declared in app config).
# Usage: update-secrets.sh <app-config.json>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP_CONFIG="${1:?Usage: update-secrets.sh <app-config.json>}"
load_app_config "$APP_CONFIG"

secrets_file_rel="$(jq -r '.secretsFile // "secrets/.env"' "$APP_CONFIG")"
SECRETS_FILE="$STACK_PATH/$secrets_file_rel"

if ! jq -e '.secretsFromEnv | length > 0' "$APP_CONFIG" >/dev/null 2>&1; then
  exit 0
fi

log_section "Update runtime secrets"

mkdir -p "$(dirname "$SECRETS_FILE")"
touch "$SECRETS_FILE"
chmod 600 "$SECRETS_FILE"

upsert_secret() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$SECRETS_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$SECRETS_FILE"
  else
    echo "${key}=${value}" >> "$SECRETS_FILE"
  fi
}

mapfile -t secret_keys < <(jq -r '.secretsFromEnv[]? // empty' "$APP_CONFIG")
updated=0
for key in "${secret_keys[@]}"; do
  [[ -z "$key" ]] && continue
  value="${!key:-}"
  if [[ -n "$value" ]]; then
    upsert_secret "$key" "$value"
    echo "  updated $key"
    updated=$((updated + 1))
  fi
done

if [[ $updated -eq 0 ]]; then
  echo "  no secrets provided in environment"
else
  echo "✓ $updated secret(s) updated"
fi
