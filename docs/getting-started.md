# Getting started

This guide walks you through your first deploy with OptimalyDeploy.

## Prerequisites

- A Linux server (amd64) with Docker and Docker Compose v2
- A GitHub repository for your application
- Root SSH access to the server (one-time runner setup)

## Step 1 — Prepare the server

```bash
# On the server
docker --version          # 24+
docker compose version    # v2 plugin

mkdir -p /srv/docker/myapp/secrets
# Create secrets/.env manually before first deploy (DB passwords, API keys, …)
```

## Step 2 — Install the runner

From your laptop (needs `gh` CLI authenticated):

```bash
REGISTRATION_TOKEN=$(gh api -X POST orgs/YOUR-ORG/actions/runners/registration-token --jq .token)

scp deploy/install/install-runner.sh root@YOUR-SERVER:/tmp/
ssh root@YOUR-SERVER \
  "REGISTRATION_TOKEN=$REGISTRATION_TOKEN bash /tmp/install-runner.sh \
    --org YOUR-ORG \
    --labels 'self-hosted,linux,x64,server-myapp' \
    --name myapp \
    --stack-path /srv/docker/myapp"
```

Verify in GitHub → **Settings → Actions → Runners** (org or repo level).

## Step 3 — Add deploy config to your app repo

### servers.json

```json
{
  "servers": {
    "myapp-prod": {
      "description": "Production server",
      "hostname": "myapp.example.com",
      "runnerLabels": ["self-hosted", "linux", "x64", "server-myapp"],
      "deployMode": "build-on-runner"
    }
  }
}
```

Place at `.github/deploy/config/servers.json`.

### app config

Copy [`config/apps/_template.json`](../config/apps/_template.json) to  
`.github/deploy/config/apps/myapp-production.json` and edit paths, images, health check.

## Step 4 — Add the workflow

Copy [`examples/minimal/deploy.yml`](../examples/minimal/deploy.yml) to  
`.github/workflows/deploy.yml`. Adjust `target` and `test_solution`.

## Step 5 — Push and watch

```bash
git push origin main
```

Open **Actions** tab. The job should land on your self-hosted runner, build the image, and restart compose.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Job queued forever | Runner offline — check `systemctl status actions.runner.*` |
| `exec format error` | Image built on wrong arch — must use build-on-runner |
| Health check 000 | Wrong Docker network name — run `docker network ls` |
| Permission denied on `/srv/...` | Re-run install-runner with `--stack-path` |
| Secrets not applied | Add to `secretsFromEnv` + GitHub Secrets with same name |
