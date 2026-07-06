#!/usr/bin/env bash
# Install a GitHub Actions self-hosted runner on a Linux deploy server.
# Run once as root on the target host.
#
# Organization runner (recommended — serves all repos in the org):
#   REGISTRATION_TOKEN=$(gh api -X POST orgs/Optimaly-net/actions/runners/registration-token --jq .token)
#   ./install-runner.sh \
#     --org Optimaly-net \
#     --labels "server-patriot,linux,x64" \
#     --name patriot \
#     --stack-path /srv/docker/patriot
#
# Repository runner:
#   REGISTRATION_TOKEN=$(gh api -X POST repos/OWNER/REPO/actions/runners/registration-token --jq .token)
#   ./install-runner.sh \
#     --url https://github.com/OWNER/REPO \
#     --labels "server-patriot" \
#     --name patriot

set -euo pipefail

RUNNER_VERSION="${RUNNER_VERSION:-2.335.1}"
RUNNER_DIR="${RUNNER_DIR:-/opt/actions-runner}"
RUNNER_USER="${RUNNER_USER:-github-runner}"
REPO_URL=""
ORG_NAME=""
LABELS=""
RUNNER_NAME="$(hostname -s)"
STACK_PATHS=()

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) REPO_URL="$2"; shift 2 ;;
    --org) ORG_NAME="$2"; shift 2 ;;
    --labels) LABELS="$2"; shift 2 ;;
    --name) RUNNER_NAME="$2"; shift 2 ;;
    --dir) RUNNER_DIR="$2"; shift 2 ;;
    --stack-path) STACK_PATHS+=("$2"); shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -n "$LABELS" ]] || { echo "ERROR: --labels required" >&2; exit 1; }
[[ -n "${REGISTRATION_TOKEN:-}" ]] || { echo "ERROR: REGISTRATION_TOKEN env required" >&2; exit 1; }

if [[ -n "$ORG_NAME" ]]; then
  CONFIG_URL="https://github.com/${ORG_NAME}"
elif [[ -n "$REPO_URL" ]]; then
  CONFIG_URL="$REPO_URL"
else
  echo "ERROR: provide --org OR --url" >&2
  exit 1
fi

echo "Installing runner: $RUNNER_NAME"
echo "  URL:    $CONFIG_URL"
echo "  Labels: $LABELS"
echo "  Dir:    $RUNNER_DIR"

if ! id "$RUNNER_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$RUNNER_USER"
  echo "Created user: $RUNNER_USER"
fi
usermod -aG docker "$RUNNER_USER"

mkdir -p "$RUNNER_DIR"
chown "$RUNNER_USER:docker" "$RUNNER_DIR"

su - "$RUNNER_USER" -s /bin/bash -c "
  set -e
  cd '$RUNNER_DIR'
  if [[ ! -f ./config.sh ]]; then
    curl -fsSL -o actions-runner.tar.gz \
      'https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz'
    tar xzf actions-runner.tar.gz && rm actions-runner.tar.gz
  fi
  ./config.sh --url '$CONFIG_URL' --token '$REGISTRATION_TOKEN' \
    --labels '$LABELS' --name '$RUNNER_NAME' --unattended --replace
"

cd "$RUNNER_DIR"
./svc.sh install "$RUNNER_USER"
./svc.sh start
./svc.sh status

for stack in "${STACK_PATHS[@]}"; do
  if [[ -d "$stack" ]]; then
    chown -R "$RUNNER_USER:docker" "$stack"
    if [[ -d "$stack/secrets" ]]; then
      chmod 750 "$stack/secrets"
      chmod 640 "$stack/secrets/.env" 2>/dev/null || true
    fi
    echo "  stack permissions: $stack → $RUNNER_USER:docker"
  fi
done

echo ""
echo "✓ Runner installed and running: $RUNNER_NAME [$LABELS]"
