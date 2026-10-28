#!/usr/bin/env bash

# Source this file from direnv or dev scripts. It intentionally keeps local dev
# database URLs derived from HMUX_PORT so parallel worktrees cannot hit the same
# Postgres instance by accident.

hmux_web_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

hmux_existing_hmux_port_set="${HMUX_PORT+x}"
hmux_existing_hmux_port="${HMUX_PORT-}"
hmux_existing_port_set="${PORT+x}"
hmux_existing_port="${PORT-}"
hmux_existing_db_port_offset_set="${HMUX_DB_PORT_OFFSET+x}"
hmux_existing_db_port_offset="${HMUX_DB_PORT_OFFSET-}"
hmux_existing_db_port_set="${HMUX_DB_PORT+x}"
hmux_existing_db_port="${HMUX_DB_PORT-}"
hmux_existing_db_user_set="${HMUX_DB_USER+x}"
hmux_existing_db_user="${HMUX_DB_USER-}"
hmux_existing_db_password_set="${HMUX_DB_PASSWORD+x}"
hmux_existing_db_password="${HMUX_DB_PASSWORD-}"
hmux_existing_db_name_set="${HMUX_DB_NAME+x}"
hmux_existing_db_name="${HMUX_DB_NAME-}"

hmux_extra_secret_file="${HMUXTERM_EXTRA_ENV_FILE:-${HMUX_WEB_EXTRA_ENV_FILE:-}}"
if [[ -z "$hmux_extra_secret_file" && -f "$HOME/.secrets/hmux.env" ]]; then
  hmux_extra_secret_file="$HOME/.secrets/hmux.env"
fi

hmux_secret_file="${HMUXTERM_ENV_FILE:-${HMUX_WEB_ENV_FILE:-}}"
if [[ -z "$hmux_secret_file" ]]; then
  if [[ -f "$HOME/.secrets/hmuxterm-dev.env" ]]; then
    hmux_secret_file="$HOME/.secrets/hmuxterm-dev.env"
  elif [[ -f "$HOME/.secret/hmuxterm.env" ]]; then
    hmux_secret_file="$HOME/.secret/hmuxterm.env"
  elif [[ -f "$HOME/.secrets/hmuxterm.env" ]]; then
    hmux_secret_file="$HOME/.secrets/hmuxterm.env"
  else
    echo "Missing hmux web secrets. Expected ~/.secrets/hmuxterm-dev.env." >&2
    return 1 2>/dev/null || exit 1
  fi
fi

hmux_nounset_was_enabled=0
case "$-" in
  *u*) hmux_nounset_was_enabled=1 ;;
esac
set +u
set -a
if [[ -n "$hmux_extra_secret_file" ]]; then
  # shellcheck disable=SC1090
  source "$hmux_extra_secret_file"
fi
# shellcheck disable=SC1090
source "$hmux_secret_file"
set +a
if ! grep -q '^STACK_SUPER_SECRET_ADMIN_KEY=' "$hmux_secret_file"; then
  unset STACK_SUPER_SECRET_ADMIN_KEY
fi

# Vercel intentionally redacts sensitive values when an environment is pulled.
# Recover the staging relay signer from a chmod-600 local file so downloaded
# environments cannot silently start a web server that never publishes Iroh.
hmux_relay_policy_key_file="${HMUX_RELAY_POLICY_PRIVATE_KEY_FILE:-$HOME/.secrets/hmux-staging-relay-policy-2026-08.pem}"
if [[ -z "${HMUX_RELAY_POLICY_PRIVATE_KEY_PEM:-}" && -f "$hmux_relay_policy_key_file" ]]; then
  # The key id and private key are one cryptographic identity. A Vercel pull can
  # leave the old, non-secret key id populated while redacting the private key;
  # retaining that id would advertise a signer different from the local PEM.
  export HMUX_RELAY_POLICY_KEY_ID="${HMUX_RELAY_POLICY_LOCAL_KEY_ID:-hmux-staging-relay-policy-2026-08}"
  export HMUX_RELAY_POLICY_PRIVATE_KEY_PEM="$(< "$hmux_relay_policy_key_file")"
fi

if [[ "$hmux_nounset_was_enabled" == "1" ]]; then
  set -u
fi

if [[ -n "$hmux_existing_hmux_port_set" ]]; then export HMUX_PORT="$hmux_existing_hmux_port"; fi
if [[ -n "$hmux_existing_port_set" ]]; then export PORT="$hmux_existing_port"; fi
if [[ -n "$hmux_existing_db_port_offset_set" ]]; then export HMUX_DB_PORT_OFFSET="$hmux_existing_db_port_offset"; fi
if [[ -n "$hmux_existing_db_port_set" ]]; then export HMUX_DB_PORT="$hmux_existing_db_port"; fi
if [[ -n "$hmux_existing_db_user_set" ]]; then export HMUX_DB_USER="$hmux_existing_db_user"; fi
if [[ -n "$hmux_existing_db_password_set" ]]; then export HMUX_DB_PASSWORD="$hmux_existing_db_password"; fi
if [[ -n "$hmux_existing_db_name_set" ]]; then export HMUX_DB_NAME="$hmux_existing_db_name"; fi

hmux_port="${HMUX_PORT:-${PORT:-3777}}"
if [[ ! "$hmux_port" =~ ^[0-9]+$ ]]; then
  echo "HMUX_PORT must be numeric, got: $hmux_port" >&2
  return 2 2>/dev/null || exit 2
fi
export HMUX_PORT="$hmux_port"

hmux_db_offset="${HMUX_DB_PORT_OFFSET:-10000}"
if [[ ! "$hmux_db_offset" =~ ^[0-9]+$ ]]; then
  echo "HMUX_DB_PORT_OFFSET must be numeric, got: $hmux_db_offset" >&2
  return 2 2>/dev/null || exit 2
fi
export HMUX_DB_PORT_OFFSET="$hmux_db_offset"

export HMUX_DB_USER="${HMUX_DB_USER:-hmux}"
export HMUX_DB_PASSWORD="${HMUX_DB_PASSWORD:-hmux}"
export HMUX_DB_NAME="${HMUX_DB_NAME:-hmux}"
export HMUX_DB_PORT="${HMUX_DB_PORT:-$((hmux_port + hmux_db_offset))}"

hmux_external_database_url="${PLANETSCALE_DATABASE_URL:-${DATABASE_URL:-}}"
if [[ "${HMUX_DEV_USE_PLANETSCALE:-0}" == "1" || "${HMUX_DEV_USE_EXTERNAL_DATABASE_URL:-0}" == "1" ]]; then
  if [[ -z "$hmux_external_database_url" ]]; then
    echo "HMUX_DEV_USE_PLANETSCALE=1 requires PLANETSCALE_DATABASE_URL or DATABASE_URL" >&2
    return 1 2>/dev/null || exit 1
  fi
  export DATABASE_URL="$hmux_external_database_url"
  export DIRECT_DATABASE_URL="$hmux_external_database_url"
elif [[ "${HMUX_DEV_USE_EXTERNAL_DATABASE_URL:-0}" != "1" ]]; then
  export DATABASE_URL="postgres://${HMUX_DB_USER}:${HMUX_DB_PASSWORD}@localhost:${HMUX_DB_PORT}/${HMUX_DB_NAME}"
  export DIRECT_DATABASE_URL="$DATABASE_URL"
elif [[ -z "${DIRECT_DATABASE_URL:-}" && -n "${DATABASE_URL:-}" ]]; then
  export DIRECT_DATABASE_URL="$DATABASE_URL"
fi

# Cloud private networks and tunnels are named from the Stack user id, and
# production, staging, and every dev database share one Freestyle account.
# Without a namespace a dev stack enrolls its tunnels into the user's
# production network and nothing ever removes them. Name the namespace after
# the database this server uses: a shared PlanetScale branch shares one, and
# every local or dev-backend Postgres (its own port and password) gets its own.
# An explicit value, even empty (production), wins.
if [[ -z "${HMUX_VM_NETWORK_NAMESPACE+x}" ]]; then
  if [[ "${HMUX_DEV_USE_PLANETSCALE:-0}" == "1" ]]; then
    hmux_network_identity="$DATABASE_URL"
  else
    hmux_network_identity="${HMUX_DB_USER}:${HMUX_DB_PASSWORD}@${HMUX_DB_PORT}/${HMUX_DB_NAME}#${HMUX_PORT}"
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    hmux_network_hash="$(printf '%s' "$hmux_network_identity" | sha256sum)"
  else
    hmux_network_hash="$(printf '%s' "$hmux_network_identity" | shasum -a 256)"
  fi
  export HMUX_VM_NETWORK_NAMESPACE="dev-${hmux_network_hash:0:10}"
  unset hmux_network_identity hmux_network_hash
fi

if [[ "${HMUX_DEV_USE_EXTERNAL_VM_API_BASE_URL:-0}" != "1" ]]; then
  export HMUX_VM_API_BASE_URL="http://localhost:${HMUX_PORT}"
fi

# Local Cloud VM dogfood uses Freestyle (the public platform) by default. A
# caller can still opt into another provider explicitly with
# HMUX_VM_DEFAULT_PROVIDER.
export HMUX_VM_DEFAULT_PROVIDER="${HMUX_VM_DEFAULT_PROVIDER:-freestyle}"

# Local dev should not require a checked-in or per-worktree .env.local just to pass
# startup validation for routes the developer is not exercising.
export RESEND_API_KEY="${RESEND_API_KEY:-hmux-local-dev}"
export HMUX_FEEDBACK_FROM_EMAIL="${HMUX_FEEDBACK_FROM_EMAIL:-dev@example.invalid}"
export HMUX_FEEDBACK_RATE_LIMIT_ID="${HMUX_FEEDBACK_RATE_LIMIT_ID:-hmux-feedback-local}"
export HMUX_CLIENT_CONFIG_RATE_LIMIT_ID="${HMUX_CLIENT_CONFIG_RATE_LIMIT_ID:-hmux-client-config-local}"

export HMUX_WEB_SECRET_ENV_FILE="$hmux_secret_file"
export HMUX_WEB_EXTRA_SECRET_ENV_FILE="$hmux_extra_secret_file"
export PATH="$hmux_web_dir/node_modules/.bin:$PATH"
