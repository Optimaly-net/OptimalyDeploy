# Deploy gotchas

Lessons from production Patriot deploy (July 2026). Read before your first pipeline run.

## 1. Tests on ubuntu-latest, deploy on self-hosted

Self-hosted runner user (`github-runner`) cannot install .NET SDK to `/usr/share/dotnet`.

**Pattern:** separate `test` job on `ubuntu-latest`, then `deploy` job on `[self-hosted, server-*]`.

## 2. Do not run Eval/integration harness in CI

`dotnet test` on the whole solution may pick up benchmark/eval projects.

**Fix:** loop only unit test projects:

```bash
for proj in tests/MyApp.*.Tests/*.csproj; do
  dotnet test "$proj" -c Release --no-restore
done
```

## 3. Secret interpolation in docker-compose can resolve empty

If compose has `Inference__Mistral__ApiKey: ${MISTRAL_API_KEY}` AND `env_file: secrets/.env`,  
GitHub-injected empty env vars override file values during `docker compose up`.

**Fix:**

- Store secrets only in `secrets/.env` on the server
- Remove duplicate `${VAR}` lines from compose for those keys
- Use `secretMappings` to duplicate short keys → ASP.NET `__` names in `.env`

## 4. Health check via `docker exec`, not Docker network DNS

`patriot_patriot-net` DNS for `patriot-web` often fails from ephemeral curl containers.

**Fix:**

```json
"healthCheck": {
  "container": "patriot-web",
  "url": "http://localhost:8080/health",
  "maxAttempts": 12,
  "retryDelaySeconds": 5
}
```

## 5. Force container recreate after image rebuild

`docker compose up --force-recreate` alone may leave stale state.

**Fix:** `docker rm -f <service>` before compose up (handled by `deploy-compose.sh`).

## 6. Build on the target server (amd64)

Never `docker save` an image built on Apple Silicon.

**Fix:** `deployMode: build-on-runner` on the production host.

## 7. Copy secrets before compose

Always `cp secrets/.env .env` immediately before `docker compose up`.

Handled by `deploy-compose.sh` when `envFile.copyFrom` is set.
