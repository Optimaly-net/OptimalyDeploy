# App config guide

Each deploy target is defined by a JSON file, typically at  
`.github/deploy/config/apps/<target>.json`.

Validate against [`deploy/schema/app-config.schema.json`](../deploy/schema/app-config.schema.json).

## Core fields

### Identity

```json
{
  "id": "myapp-production",
  "projectCode": "myapp",
  "environment": "production",
  "concurrencyGroup": "myapp-production"
}
```

`concurrencyGroup` prevents parallel deploys of the same app.

### Server routing

```json
{
  "server": "myapp-prod"
}
```

Must match a key in `servers.json`. The runner labels from that entry determine `runs-on`.

### Stack

```json
{
  "stackPath": "/srv/docker/myapp",
  "composeFile": "docker-compose.yml",
  "composeProfiles": ["app"],
  "versionVar": "APP_VERSION"
}
```

`composeProfiles` maps to `docker compose --profile`.

### Images

```json
{
  "images": [
    {
      "name": "myapp-web",
      "dockerfile": "Dockerfile",
      "context": ".",
      "buildArgs": ["BUILD_VERSION=1.0"]
    }
  ]
}
```

Built locally on the runner. Tags: `:latest` and `:$GITHUB_RUN_ID`.

### Services

```json
{
  "services": ["myapp-web"]
}
```

Container names passed to `docker compose up --force-recreate --no-deps`.

### Stack assets

Files copied from repo checkout to server stack before deploy:

```json
{
  "stackAssets": [
    { "src": "deploy/docker-compose.yml", "dest": "docker-compose.yml" },
    { "src": "deploy/caddy/Caddyfile", "dest": "caddy/Caddyfile" }
  ]
}
```

Paths in `src` are relative to your **app repo root**.

### Secrets

```json
{
  "secretsFile": "secrets/.env",
  "secretsFromEnv": ["MISTRAL_API_KEY", "SMTP_PASSWORD"],
  "envFile": {
    "copyFrom": "secrets/.env",
    "copyTo": ".env"
  }
}
```

During deploy, each name in `secretsFromEnv` is read from the GitHub Actions environment (set via repository secrets) and upserted into `secretsFile` on the server.

### Health check

```json
{
  "healthCheck": {
    "network": "myapp_myapp-net",
    "url": "http://myapp-web:8080/health",
    "hostHeader": "app.example.com",
    "timeoutSeconds": 30,
    "minCode": 200,
    "maxCode": 299,
    "retries": 6,
    "retryDelaySeconds": 5
  },
  "publicUrl": "https://app.example.com"
}
```

- `network` — Docker network for an ephemeral curl container
- `hostHeader` — optional, when probing through Caddy
- `retries` — useful for slow .NET cold starts

### Hooks

Project-specific logic without forking the framework:

```json
{
  "hooks": {
    "preDeploy": ".github/deploy/hooks/pre-deploy.sh",
    "postDeploy": ".github/deploy/hooks/post-deploy.sh"
  }
}
```

Scripts receive `<app-config.json>` as the first argument. Must be executable.

### Post-deploy

```json
{
  "postDeploy": {
    "waitSeconds": 15,
    "pruneImagesHours": 72
  }
}
```

`pruneImagesHours: 0` disables image cleanup.

## Multi-image apps

See [`examples/slp/app-config.json`](../examples/slp/app-config.json) — three images, three services, one deploy.

## Single-service .NET app

See [`examples/patriot/app-config.json`](../examples/patriot/app-config.json).
