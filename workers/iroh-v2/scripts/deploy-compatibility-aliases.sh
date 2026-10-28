#!/usr/bin/env bash
set -euo pipefail

# The canonical Workers are renamed in place so their Durable Object data is
# retained. These aliases preserve old app builds until they age out.
cd "$(dirname "$0")/.."
bun scripts/check-compatibility-aliases.ts

for pair in \
  "hmux-iroh-v2:hmux-v2" \
  "hmux-iroh-v2-staging:hmux-v2-staging" \
  "hmux-iroh-v2-development:hmux-v2-development"; do
  old_name="${pair%%:*}"
  canonical_name="${pair##*:}"
  config_dir="$(mktemp -d "${TMPDIR:-/tmp}/hmux-v2-alias.XXXXXX")"
  config="$config_dir/wrangler.jsonc"
  cat >"$config" <<JSON
{
  "\$schema": "$(pwd)/node_modules/wrangler/config-schema.json",
  "name": "$old_name",
  "main": "$(pwd)/aliases/index.ts",
  "compatibility_date": "2026-09-10",
  "workers_dev": true,
  "preview_urls": false,
  "services": [{ "binding": "CANONICAL", "service": "$canonical_name" }]
}
JSON
  echo "Deploying compatibility alias: $old_name -> $canonical_name"
  bunx wrangler deploy --config "$config"
done
