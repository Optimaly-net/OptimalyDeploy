# Changelog

## v1.0.0 — 2026-07-06

Initial public release — extracted from battle-tested Patriot production deploy.

- Config-driven deploy framework (`deploy/scripts/`)
- Reusable GitHub Actions workflow (tests on ubuntu-latest, deploy on self-hosted)
- `normalize-secrets.sh` — ASP.NET `__` env var mapping
- Health check via `docker exec` with retries
- `deploy-compose.sh` — force recreate, required secret validation
- Self-hosted runner installer (org + repo level)
- JSON Schema, examples (Patriot, SLP), gotchas doc
