#!/usr/bin/env bash
# Health check after deploy — container exec, docker network, or direct HTTP.
# Usage: health-check.sh <app-config.json>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP_CONFIG="${1:?Usage: health-check.sh <app-config.json>}"
load_app_config "$APP_CONFIG"

CONTAINER="$(jq -r '.healthCheck.container // empty' "$APP_CONFIG")"
NETWORK="$(jq -r '.healthCheck.network // empty' "$APP_CONFIG")"
URL="$(jq -r '.healthCheck.url' "$APP_CONFIG")"
HOST_HEADER="$(jq -r '.healthCheck.hostHeader // empty' "$APP_CONFIG")"
TIMEOUT="$(jq -r '.healthCheck.timeoutSeconds // 15' "$APP_CONFIG")"
MIN_CODE="$(jq -r '.healthCheck.minCode // 200' "$APP_CONFIG")"
MAX_CODE="$(jq -r '.healthCheck.maxCode // 499' "$APP_CONFIG")"
MAX_ATTEMPTS="$(jq -r '.healthCheck.maxAttempts // .healthCheck.retries // 12' "$APP_CONFIG")"
RETRY_DELAY="$(jq -r '.healthCheck.retryDelaySeconds // 5' "$APP_CONFIG")"

log_section "Health check · $APP_ID"

check_code() {
  local code="000"
  if [[ -n "$CONTAINER" ]]; then
    code="$(docker exec "$CONTAINER" curl -sS -o /dev/null -w "%{http_code}" -m "$TIMEOUT" "$URL" 2>/dev/null || echo "000")"
  elif [[ -n "$NETWORK" ]]; then
    local curl_args=(-sS -o /dev/null -w "%{http_code}" -m "$TIMEOUT")
    [[ -n "$HOST_HEADER" ]] && curl_args+=(-H "Host: $HOST_HEADER")
    code="$(docker run --rm --network "$NETWORK" curlimages/curl:8.5.0 \
      curl "${curl_args[@]}" "$URL" 2>/dev/null || echo "000")"
  else
    local curl_args=(-sS -o /dev/null -w "%{http_code}" -m "$TIMEOUT")
    [[ -n "$HOST_HEADER" ]] && curl_args+=(-H "Host: $HOST_HEADER")
    code="$(curl "${curl_args[@]}" "$URL" 2>/dev/null || echo "000")"
  fi
  echo "$code"
}

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  code="$(check_code)"
  echo "  attempt $attempt/$MAX_ATTEMPTS → HTTP $code (expected ${MIN_CODE}-${MAX_CODE})"
  if [[ "$code" -ge "$MIN_CODE" && "$code" -le "$MAX_CODE" ]]; then
    if [[ -n "$PUBLIC_URL" ]]; then
      echo "✓ Deploy complete: $PUBLIC_URL"
    else
      echo "✓ Health check passed"
    fi
    exit 0
  fi
  sleep "$RETRY_DELAY"
done

echo "ERROR: Health check failed after $MAX_ATTEMPTS attempt(s)" >&2
exit 1
