# Server setup

## Runner placement

Install **one runner per server where Docker builds and runs your containers**.

Do not try to build on a Mac/CI runner and copy images to production — you will hit architecture mismatches (`exec /usr/bin/dotnet: exec format error`).

## Org vs repo runners

| Type | Registration | Best for |
|------|-------------|----------|
| **Organization** | `--org Optimaly-net` | Multiple app repos on same server |
| **Repository** | `--url https://github.com/org/repo` | Single-repo dedicated servers |

Organization runners require GitHub Team for private repos.

## Install script

[`deploy/install/install-runner.sh`](../deploy/install/install-runner.sh)

```bash
REGISTRATION_TOKEN=... ./install-runner.sh \
  --org YOUR-ORG \
  --labels "self-hosted,linux,x64,server-myapp" \
  --name myapp \
  --dir /opt/actions-runner-myapp \
  --stack-path /srv/docker/myapp
```

### What it does

1. Creates `github-runner` user (if missing)
2. Adds user to `docker` group
3. Downloads GitHub Actions runner
4. Registers with your labels
5. Installs systemd service
6. Sets ownership on stack path for the runner user

## Permissions

The runner user needs:

- **docker** group — build and compose commands
- **write access** to `/srv/docker/your-app` — sync stack assets
- **read/write** to `secrets/.env` — secret upsert during deploy

The install script handles this when you pass `--stack-path`.

## Health checks

Prefer internal Docker network probes over public URL curls from the runner:

```json
"healthCheck": {
  "network": "myapp_myapp-net",
  "url": "http://myapp-web:8080/health"
}
```

Runners inside containers or locked-down hosts often cannot reach public HTTPS even when the app is fine.

## Updating the runner

```bash
cd /opt/actions-runner-myapp
./svc.sh stop
# download new version, re-config if needed
./svc.sh start
```

See [GitHub runner releases](https://github.com/actions/runner/releases).
