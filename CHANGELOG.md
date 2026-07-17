# Changelog

## Unreleased

- Declare `LINKUP_API_KEY` in reusable deploy `workflow_call` secrets and pass it into `deploy.sh` env (Patriot Linkup web search). Callers that pass undeclared secrets were failing with Actions `startup_failure`.
- `build-images.sh` now injects `GIT_VERSION` / app `versionVar` / `GIT_COMMIT_HASH` from `version.json` + git SHA so Docker builds bake a real version (not Dockerfile default `dev`).

## v1.0.0 — 2026-07-06

Initial public release — extracted from battle-tested Patriot production deploy.

- Config-driven deploy framework (`deploy/scripts/`)
- Reusable GitHub Actions workflow (tests on ubuntu-latest, deploy on self-hosted)
- `normalize-secrets.sh` — ASP.NET `__` env var mapping
- Health check via `docker exec` with retries
- `deploy-compose.sh` — force recreate, required secret validation
- Self-hosted runner installer (org + repo level)
- JSON Schema, examples (Patriot, SLP), gotchas doc
