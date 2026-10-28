---
name: hmux-backend
description: "Backend TypeScript and Cloud VM development rules for hmux. Use when editing web/app/api, web/services, backend scripts, Cloud VM lifecycle, provider integrations, Postgres, Stack Auth pricing gates, migrations, or provider image build scripts."
---

# hmux Backend

## Core rules

- Default backend TypeScript to Effect under `web/app/api/**`, `web/services/**`, and backend scripts touching providers, databases, auth, rate limits, retries, timeouts, or telemetry.
- Keep Next route handlers thin: parse the request, run one Effect program at the boundary, map typed errors to HTTP responses, treat unexpected defects separately.
- Plain TypeScript is for trivial data shapes, constants, config files, frontend React, and small glue where Effect would add ceremony without improving failure handling.
- Cloud VM backend logic stays in Vercel route handlers and Effect services backed by Postgres. Do not reintroduce Rivet or a raw actor protocol unless a later architecture doc explicitly changes the control plane.
- Postgres is the source of truth for VM lifecycle, active VM limits, idempotency, and usage events.
- Production and staging Cloud VM Postgres use PlanetScale PostgreSQL database `hmux-prod` in organization `hmux`. The runtime reads `DATABASE_URL` with `HMUX_DB_DRIVER=url`; migration jobs use the protected `DATABASE_URL` secret. AWS credentials are not database credentials.
- Run production/staging migrations with `bun run cloud-vm:migrate -- staging` followed by `-- production`; never from Vercel build or route startup. Local dev keeps the `HMUX_PORT`-derived Docker Postgres path from `bun dev`.
- Cloud VM create pricing gates use Stack Auth team payment items when enabled.

## Secrets

Cloud VM build, test, and local dev scripts read provider secrets from `~/.secrets/hmux.env`: `FREESTYLE_API_KEY` and the R2 upload vars `web/scripts/build-cloud-vm-images.ts` needs when creating Freestyle snapshots.

```bash
set -a
source ~/.secrets/hmux.env
set +a
```

`~/.secrets/hmuxterm-dev.env` holds local Stack/web env and not the provider build keys. `bun dev` sources `~/.secrets/hmux.env` first when present, then `~/.secrets/hmuxterm-dev.env`, so hmuxterm-specific Stack settings override broader hmux secrets. The web dev loader still accepts the legacy `~/.secret/hmuxterm.env` and `~/.secrets/hmuxterm.env` paths while machines migrate.

## Detailed references

- [references/effect-boundaries.md](references/effect-boundaries.md): route handlers, services, typed errors, retries, dependency injection.
- [references/cloud-vm-control-plane.md](references/cloud-vm-control-plane.md): VM lifecycle, migrations, Postgres, provider idempotency, pricing gates.
