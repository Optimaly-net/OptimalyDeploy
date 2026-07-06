#!/usr/bin/env bash
# OptimalyDeploy — full deploy pipeline driven by app config JSON.
# Usage: deploy.sh <app-config.json>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP_CONFIG="${1:?Usage: deploy.sh <app-config.json>}"
load_app_config "$APP_CONFIG"

VERSION="$(read_version_label)"
PRUNE_HOURS="$(jq -r '.postDeploy.pruneImagesHours // 72' "$APP_CONFIG")"
PRE_HOOK="$(jq -r '.hooks.preDeploy // empty' "$APP_CONFIG")"
POST_HOOK="$(jq -r '.hooks.postDeploy // empty' "$APP_CONFIG")"

log_section "OptimalyDeploy · $APP_ID"
echo "Version:  $VERSION"
echo "Server:   ${SERVER_HOSTNAME:-$SERVER_KEY}"
echo "Stack:    $STACK_PATH/$COMPOSE_FILE"
echo "Mode:     $DEPLOY_MODE"
echo "Repo:     $REPO_ROOT"

run_hook_if_present "$PRE_HOOK" pre

"$SCRIPT_DIR/update-secrets.sh" "$APP_CONFIG"
"$SCRIPT_DIR/normalize-secrets.sh" "$APP_CONFIG"
"$SCRIPT_DIR/sync-stack.sh" "$APP_CONFIG"
"$SCRIPT_DIR/build-images.sh" "$APP_CONFIG"
"$SCRIPT_DIR/deploy-compose.sh" "$APP_CONFIG"
"$SCRIPT_DIR/health-check.sh" "$APP_CONFIG"

run_hook_if_present "$POST_HOOK" post

if [[ "$PRUNE_HOURS" -gt 0 ]]; then
  echo "Pruning dangling images older than ${PRUNE_HOURS}h..."
  docker image prune -f --filter "until=${PRUNE_HOURS}h" || true
fi

echo ""
echo "✓ Deployment finished successfully."
