# OptimalyDeploy

[![CI](https://github.com/Optimaly-net/OptimalyDeploy/actions/workflows/ci.yml/badge.svg)](https://github.com/Optimaly-net/OptimalyDeploy/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Config-driven Docker deploy framework for GitHub Actions.**

Build on the production server (amd64), deploy with `docker compose`, verify with an internal health check — no image registry, no SSH tarballs, no ARM/x64 surprises.

Born from production use at [Optimaly](https://optimaly.net) (Patriot, SladkaPohotovost, and friends). Extracted so every new project gets the same battle-tested pipeline in ~15 minutes.

---

## Why this exists

| Problem | OptimalyDeploy answer |
|---------|----------------------|
| `docker save` over SSH from a Mac | Build on the target server's runner |
| Duplicated deploy scripts per repo | One framework, thin config per app |
| Per-repo runner registration | Org-level runner + `server-*` labels |
| Public URL smoke tests from CI | Health check via internal Docker network |
| Secret sprawl | Declarative `secretsFromEnv` in app config |

---

## Architecture

```
┌─────────────────────┐     push main      ┌──────────────────────────┐
│  Your app repo      │ ─────────────────► │  GitHub Actions          │
│  Dockerfile         │                    │  uses OptimalyDeploy@v1  │
│  deploy/compose     │                    └────────────┬─────────────┘
│  .github/deploy/    │                                 │
│    config/*.json    │                                 │ routes by label
└─────────────────────┘                                 ▼
                                            ┌──────────────────────────┐
                                            │  Self-hosted runner      │
                                            │  on production server    │
                                            │  (build-on-runner)       │
                                            └────────────┬─────────────┘
                                                         │
                    checkout → build → compose up → health check
                                                         ▼
                                            ┌──────────────────────────┐
                                            │  /srv/docker/your-app    │
                                            │  postgres · caddy · web  │
                                            └──────────────────────────┘
```

**One runner per deploy server**, not one global agent. The universal part is the **framework** — scripts, workflow, conventions.

---

## Quick start

### 1. Install a runner on your server

```bash
# Org-level runner (recommended — serves all repos in the org)
REGISTRATION_TOKEN=$(gh api -X POST orgs/YOUR-ORG/actions/runners/registration-token --jq .token)

curl -fsSL https://raw.githubusercontent.com/Optimaly-net/OptimalyDeploy/v1/deploy/install/install-runner.sh | bash -s -- \
  --org YOUR-ORG \
  --labels "self-hosted,linux,x64,server-myapp" \
  --name myapp \
  --stack-path /srv/docker/myapp
```

### 2. Add config to your app repo

```
your-repo/
├── Dockerfile
├── deploy/
│   └── docker-compose.yml
└── .github/
    ├── workflows/deploy.yml          ← 10 lines, calls OptimalyDeploy
    └── deploy/config/
        ├── servers.json
        └── apps/myapp-production.json
```

Copy [`config/apps/_template.json`](config/apps/_template.json) and [`config/servers.example.json`](config/servers.example.json) as starting points.

### 3. Wire the workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: Optimaly-net/OptimalyDeploy/.github/workflows/deploy-reusable.yml@v1
    with:
      target: myapp-production
      test_solution: src/MyApp.sln
    secrets: inherit
```

Push to `main`. Done.

---

## App config reference

Each deploy target is a JSON file. See [`config/apps/_template.json`](config/apps/_template.json) and [JSON Schema](deploy/schema/app-config.schema.json).

| Field | Purpose |
|-------|---------|
| `server` | Key into `servers.json` — selects which runner picks up the job |
| `stackPath` | Server path, e.g. `/srv/docker/myapp` |
| `images[]` | Docker images to build locally |
| `services[]` | Compose services to recreate |
| `stackAssets[]` | Files to copy from repo → stack path before deploy |
| `secretsFromEnv` | Env var names (GitHub Secrets) → `secrets/.env` |
| `healthCheck` | Internal network probe (preferred over public URL) |
| `hooks.preDeploy` | Optional script in your repo before deploy |

Real-world examples: [`examples/patriot/`](examples/patriot/) · [`examples/slp/`](examples/slp/)

---

## Deploy pipeline

`deploy.sh` runs these steps in order:

1. **preDeploy hook** (optional)
2. **update-secrets** — upsert GitHub Secrets into server `.env`
3. **sync-stack** — copy compose, Caddyfile, configs to `/srv/...`
4. **build-images** — `docker build` on the runner (native amd64)
5. **deploy-compose** — `docker compose up -d --force-recreate`
6. **health-check** — retry loop via internal Docker network
7. **postDeploy hook** + image prune

---

## Server labels convention

| Label | Meaning |
|-------|---------|
| `self-hosted` | GitHub default |
| `linux` / `x64` | Platform |
| `server-patriot` | Physical host routing |
| `server-slp` | Physical host routing |
| `server-aplikace` | Shared app server |

Workflow resolves labels from `servers.json` → GitHub routes the job to the correct machine.

---

## Project structure

```
OptimalyDeploy/
├── deploy/
│   ├── scripts/          # deploy.sh, build-images.sh, health-check.sh, …
│   ├── install/          # install-runner.sh
│   └── schema/           # JSON Schema for configs
├── config/
│   ├── servers.example.json
│   └── apps/_template.json
├── examples/
│   ├── patriot/
│   ├── slp/
│   └── minimal/deploy.yml
└── .github/workflows/
    ├── deploy-reusable.yml   # ← your app repos call this
    └── ci.yml
```

---

## Docs

- [Getting started](docs/getting-started.md) — step-by-step first deploy
- [Server setup](docs/server-setup.md) — runner installation & permissions
- [App config guide](docs/app-config.md) — all fields explained
- [Gotchas](docs/gotchas.md) — production lessons (Patriot, SLP)

---

## Used by

- [Patriot](https://github.com/Optimaly-net/Patriot) — .NET 10 Blazor SaaS
- [SladkaPohotovost](https://github.com/Optimaly-net/SladkaPohotovost) — nopCommerce e-shop

---

## License

MIT — use freely, contribute back if you improve something.
