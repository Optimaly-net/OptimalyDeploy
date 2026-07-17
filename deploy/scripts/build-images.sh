#!/usr/bin/env bash
# Build all Docker images defined in an app config (build-on-runner mode).
# Usage: build-images.sh <app-config.json> [run-id]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP_CONFIG="${1:?Usage: build-images.sh <app-config.json> [run-id]}"
RUN_ID="${2:-${GITHUB_RUN_ID:-local}}"

load_app_config "$APP_CONFIG"
log_section "Build images · $APP_ID · mode=$DEPLOY_MODE"

if [[ "$DEPLOY_MODE" != "build-on-runner" ]]; then
  echo "ERROR: build-images.sh requires deployMode=build-on-runner (got: $DEPLOY_MODE)" >&2
  exit 1
fi

cd "$REPO_ROOT"

VERSION_LABEL="$(read_version_label)"
COMMIT_HASH="${GITHUB_SHA:-}"
if [[ -z "$COMMIT_HASH" ]]; then
  COMMIT_HASH="$(git rev-parse HEAD 2>/dev/null || true)"
fi
COMMIT_SHORT="${COMMIT_HASH:0:7}"
[[ -z "$COMMIT_SHORT" ]] && COMMIT_SHORT="unknown"
if [[ "$VERSION_LABEL" == "unknown" && "$COMMIT_SHORT" != "unknown" ]]; then
  VERSION_LABEL="$COMMIT_SHORT"
fi

mapfile -t images < <(jq -c '.images[]' "$APP_CONFIG")
for image_spec in "${images[@]}"; do
  name="$(echo "$image_spec" | jq -r '.name')"
  dockerfile="$(echo "$image_spec" | jq -r '.dockerfile')"
  context="$(echo "$image_spec" | jq -r '.context')"

  build_args=(
    --build-arg "GIT_VERSION=${VERSION_LABEL}"
    --build-arg "GIT_COMMIT_HASH=${COMMIT_SHORT}"
    --build-arg "${VERSION_VAR}=${VERSION_LABEL}"
  )
  while IFS= read -r arg; do
    [[ -n "$arg" ]] && build_args+=(--build-arg "$arg")
  done < <(jq -r '.buildArgs[]? // empty' <<< "$image_spec")

  echo "→ Building $name"
  echo "  dockerfile: $dockerfile"
  echo "  context:    $context"
  echo "  version:    $VERSION_LABEL ($COMMIT_SHORT)"
  docker build \
    "${build_args[@]}" \
    -f "$dockerfile" \
    -t "${name}:latest" \
    -t "${name}:${RUN_ID}" \
    "$context"
done

echo "✓ All images built."
