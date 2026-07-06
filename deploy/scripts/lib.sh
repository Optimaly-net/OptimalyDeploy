#!/usr/bin/env bash
# OptimalyDeploy — shared helpers for config-driven deploy scripts.
set -euo pipefail

framework_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

resolve_repo_root() {
  if [[ -n "${GITHUB_WORKSPACE:-}" && -d "$GITHUB_WORKSPACE" ]]; then
    echo "$GITHUB_WORKSPACE"
    return
  fi
  if [[ -n "${OPT_REPO_ROOT:-}" && -d "$OPT_REPO_ROOT" ]]; then
    echo "$OPT_REPO_ROOT"
    return
  fi
  # Fallback: walk up from app config looking for .git
  local dir
  dir="$(cd "$(dirname "$APP_CONFIG")" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  echo "$(pwd)"
}

load_app_config() {
  local app_config="$1"

  if [[ ! -f "$app_config" ]]; then
    echo "ERROR: App config not found: $app_config" >&2
    exit 1
  fi

  APP_CONFIG="$(cd "$(dirname "$app_config")" && pwd)/$(basename "$app_config")"
  APP_ID="$(jq -r '.id' "$APP_CONFIG")"
  SERVER_KEY="$(jq -r '.server' "$APP_CONFIG")"
  STACK_PATH="$(jq -r '.stackPath' "$APP_CONFIG")"
  COMPOSE_FILE="$(jq -r '.composeFile' "$APP_CONFIG")"
  VERSION_VAR="$(jq -r '.versionVar // "APP_VERSION"' "$APP_CONFIG")"
  PUBLIC_URL="$(jq -r '.publicUrl // empty' "$APP_CONFIG")"
  REPO_ROOT="$(resolve_repo_root)"

  local servers_file="${OPT_SERVERS_FILE:-}"
  if [[ -z "$servers_file" ]]; then
    local config_dir
    config_dir="$(dirname "$APP_CONFIG")"
    if [[ -f "$config_dir/../servers.json" ]]; then
      servers_file="$(cd "$config_dir/.." && pwd)/servers.json"
    elif [[ -f "$REPO_ROOT/.github/deploy/config/servers.json" ]]; then
      servers_file="$REPO_ROOT/.github/deploy/config/servers.json"
    else
      echo "ERROR: servers.json not found. Set OPT_SERVERS_FILE or place it beside app config." >&2
      exit 1
    fi
  fi

  if [[ ! -f "$servers_file" ]]; then
    echo "ERROR: Servers config not found: $servers_file" >&2
    exit 1
  fi

  SERVERS_FILE="$servers_file"
  RUNNER_LABELS="$(jq -c --arg s "$SERVER_KEY" '.servers[$s].runnerLabels' "$SERVERS_FILE")"
  DEPLOY_MODE="$(jq -r --arg s "$SERVER_KEY" '.servers[$s].deployMode' "$SERVERS_FILE")"
  SERVER_HOSTNAME="$(jq -r --arg s "$SERVER_KEY" '.servers[$s].hostname // empty' "$SERVERS_FILE")"

  if [[ "$RUNNER_LABELS" == "null" ]]; then
    echo "ERROR: Unknown server '$SERVER_KEY' in $SERVERS_FILE" >&2
    exit 1
  fi
}

log_section() {
  echo ""
  echo "============================================"
  echo "  $1"
  echo "============================================"
}

read_version_label() {
  local version_file="${1:-$REPO_ROOT/version.json}"
  if [[ ! -f "$version_file" ]]; then
    echo "unknown"
    return
  fi
  local major minor
  major="$(jq -r '.major' "$version_file")"
  minor="$(jq -r '.minor' "$version_file")"
  echo "${major}.${minor}.${GITHUB_RUN_NUMBER:-local}"
}

run_hook_if_present() {
  local hook_path="$1"
  shift
  if [[ -z "$hook_path" || "$hook_path" == "null" ]]; then
    return 0
  fi
  local script="$REPO_ROOT/$hook_path"
  if [[ ! -f "$script" ]]; then
    echo "WARN: Hook not found: $script" >&2
    return 0
  fi
  chmod +x "$script"
  "$script" "$APP_CONFIG" "$@"
}
