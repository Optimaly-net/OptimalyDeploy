#!/usr/bin/env bash
# Sync deploy assets from app repo checkout to server stack path.
# Usage: sync-stack.sh <app-config.json>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP_CONFIG="${1:?Usage: sync-stack.sh <app-config.json>}"
load_app_config "$APP_CONFIG"

log_section "Sync stack assets → $STACK_PATH"

cd "$REPO_ROOT"

mapfile -t assets < <(jq -c '.stackAssets[]? // empty' "$APP_CONFIG")
if [[ ${#assets[@]} -eq 0 ]]; then
  echo "No stackAssets configured — skipping."
else
  for asset in "${assets[@]}"; do
    [[ -z "$asset" ]] && continue
    src="$(echo "$asset" | jq -r '.src')"
    dest="$(echo "$asset" | jq -r '.dest')"
    if [[ ! -e "$src" ]]; then
      echo "ERROR: stack asset missing: $src" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$STACK_PATH/$dest")"
    cp -a "$src" "$STACK_PATH/$dest"
    echo "  $src → $dest"
  done
fi

env_copy_from="$(jq -r '.envFile.copyFrom // empty' "$APP_CONFIG")"
env_copy_to="$(jq -r '.envFile.copyTo // ".env"' "$APP_CONFIG")"
if [[ -n "$env_copy_from" && -f "$STACK_PATH/$env_copy_from" ]]; then
  cp "$STACK_PATH/$env_copy_from" "$STACK_PATH/$env_copy_to"
  chmod 600 "$STACK_PATH/$env_copy_from" "$STACK_PATH/$env_copy_to" 2>/dev/null || true
  echo "  env: $env_copy_from → $env_copy_to"
fi

echo "✓ Stack assets synced."
