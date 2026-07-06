#!/usr/bin/env bash
# Restart compose services and verify containers are running.
# Usage: deploy-compose.sh <app-config.json>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP_CONFIG="${1:?Usage: deploy-compose.sh <app-config.json>}"
load_app_config "$APP_CONFIG"

WAIT_SECONDS="$(jq -r '.postDeploy.waitSeconds // 10' "$APP_CONFIG")"
mapfile -t services < <(jq -r '.services[]' "$APP_CONFIG")
mapfile -t profiles < <(jq -r '.composeProfiles[]? // empty' "$APP_CONFIG")

log_section "Deploy compose · $APP_ID → $STACK_PATH"

secrets_file_rel="$(jq -r '.secretsFile // "secrets/.env"' "$APP_CONFIG")"
env_file="$(jq -r '.envFile.copyTo // ".env"' "$APP_CONFIG")"

if [[ -f "$STACK_PATH/$secrets_file_rel" ]]; then
  cp "$STACK_PATH/$secrets_file_rel" "$STACK_PATH/$env_file"
  chmod 600 "$STACK_PATH/$secrets_file_rel" "$STACK_PATH/$env_file" 2>/dev/null || true
fi

mapfile -t required_keys < <(jq -r '.requiredSecrets[]? // empty' "$APP_CONFIG")
for key in "${required_keys[@]}"; do
  [[ -z "$key" ]] && continue
  if ! grep -q "^${key}=." "$STACK_PATH/$env_file" 2>/dev/null; then
    echo "ERROR: Missing or empty $key in $STACK_PATH/$env_file" >&2
    exit 1
  fi
done

cd "$STACK_PATH"
export "${VERSION_VAR}"=latest

compose_args=(-f "$COMPOSE_FILE")
for profile in "${profiles[@]}"; do
  [[ -n "$profile" ]] || continue
  compose_args+=(--profile "$profile")
done

# Force clean recreate — avoids stale container state after image rebuild
docker rm -f "${services[@]}" 2>/dev/null || true
docker compose "${compose_args[@]}" up -d --force-recreate --no-deps "${services[@]}"

echo "Waiting up to ${WAIT_SECONDS}s for containers..."
max_attempts=$(( (WAIT_SECONDS + 14) / 15 ))
for attempt in $(seq 1 "$max_attempts"); do
  sleep 15
  all_running=true
  for container in "${services[@]}"; do
    status="$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "missing")"
    if [[ "$status" != "running" ]]; then
      all_running=false
      echo "  attempt $attempt/$max_attempts: $container status=$status"
      break
    fi
  done
  if [[ "$all_running" == "true" ]]; then
    for container in "${services[@]}"; do
      echo "  ✓ $container running"
    done
    echo "✓ Compose deploy finished."
    exit 0
  fi
done

for container in "${services[@]}"; do
  status="$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "missing")"
  if [[ "$status" != "running" ]]; then
    echo "ERROR: $container is not running (status: $status)" >&2
    docker logs "$container" --tail 80 2>/dev/null || true
    exit 1
  fi
done
