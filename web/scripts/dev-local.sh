#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# On developer Macs the VM owns Next and Postgres. Never start Docker here.
if [[ "$(uname -s)" == Darwin ]]; then
  backend_helper="$ROOT_DIR/../scripts/dev-backend.sh"
  [[ -x "$backend_helper" ]] || { echo 'Shared GCP backend helper is missing; update the HQ worktree tooling.' >&2; exit 1; }
  tag="${HMUX_TAG:-}"
  if [[ -z "$tag" ]]; then
    branch="$(git -C "$ROOT_DIR/.." branch --show-current)"
    [[ -n "$branch" ]] || { echo 'Set HMUX_TAG for a detached checkout.' >&2; exit 1; }
    slug="$(printf '%s' "$branch" | tr -cs 'A-Za-z0-9._-' '-' | cut -c1-45)"
    digest="$(printf '%s' "$branch" | shasum -a 256 | cut -c1-8)"
    tag="web-${slug}-${digest}"
  fi
  "$backend_helper" start --tag "$tag" --checkout "$ROOT_DIR/.." --transport direct
  "$backend_helper" url --tag "$tag"
  exit 0
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/load-dev-env.sh"

next_pid=""
started_db=0
cleanup_watcher_pid=""
db_watchdog_pid=""
dev_lock_file=""

dev_lock_key() {
  local branch slug
  branch="$(git -C "$ROOT_DIR/.." branch --show-current 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    branch="$(basename "$(cd "$ROOT_DIR/.." && pwd)")"
  fi
  slug="$(
    printf '%s' "$branch" \
      | tr '[:upper:]' '[:lower:]' \
      | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
      | cut -c1-48
  )"
  if [[ -z "$slug" ]]; then
    slug="worktree"
  fi
  printf '%s-dev-%s' "$slug" "$HMUX_PORT"
}

claim_dev_lock() {
  local lock_dir
  lock_dir="${TMPDIR:-/tmp}/hmux-web-dev"
  mkdir -p "$lock_dir"
  dev_lock_file="$lock_dir/$(dev_lock_key).pid"
  printf '%s\n' "$$" > "$dev_lock_file"
}

owns_dev_lock() {
  [[ -n "$dev_lock_file" && -f "$dev_lock_file" && "$(cat "$dev_lock_file" 2>/dev/null)" == "$$" ]]
}

stop_local_services() {
  if ! owns_dev_lock; then
    echo "hmux web dev: skipped local service stop because another dev process owns HMUX_PORT=$HMUX_PORT"
    return
  fi
  bash "$ROOT_DIR/scripts/db-local.sh" down >/dev/null 2>&1 || true
  echo "hmux web dev: stopped local Postgres for HMUX_PORT=$HMUX_PORT"
}

start_cleanup_watcher() {
  if [[ "${HMUX_DEV_STOP_DB_ON_EXIT:-1}" == "0" ]]; then
    return
  fi

  local parent_pid=$$
  (
    trap '' INT HUP
    while kill -0 "$parent_pid" >/dev/null 2>&1; do
      sleep 1
    done
    if owns_dev_lock; then
      bash "$ROOT_DIR/scripts/db-local.sh" down >/dev/null 2>&1 || true
    fi
  ) &
  cleanup_watcher_pid=$!
}

start_db_watchdog() {
  if [[ "${HMUX_DEV_WATCH_DB:-1}" == "0" ]]; then
    return
  fi

  local parent_pid=$$
  (
    trap '' INT HUP
    while kill -0 "$parent_pid" >/dev/null 2>&1; do
      if owns_dev_lock && ! bash "$ROOT_DIR/scripts/db-local.sh" ready >/dev/null 2>&1; then
        echo "hmux web dev: local Postgres unavailable; restarting for HMUX_PORT=$HMUX_PORT"
        if bash "$ROOT_DIR/scripts/db-local.sh" up >/dev/null 2>&1; then
          bash "$ROOT_DIR/scripts/db-local.sh" migrate >/dev/null
        fi
      fi
      sleep 2
    done
  ) &
  db_watchdog_pid=$!
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM

  if [[ -n "$next_pid" ]] && kill -0 "$next_pid" >/dev/null 2>&1; then
    pkill -TERM -P "$next_pid" >/dev/null 2>&1 || true
    kill "$next_pid" >/dev/null 2>&1 || true
    wait "$next_pid" >/dev/null 2>&1 || true
  fi

  if [[ "$started_db" == "1" && "${HMUX_DEV_STOP_DB_ON_EXIT:-1}" != "0" ]]; then
    if [[ -n "$db_watchdog_pid" ]] && kill -0 "$db_watchdog_pid" >/dev/null 2>&1; then
      kill "$db_watchdog_pid" >/dev/null 2>&1 || true
      wait "$db_watchdog_pid" >/dev/null 2>&1 || true
    fi
    if [[ -n "$cleanup_watcher_pid" ]] && kill -0 "$cleanup_watcher_pid" >/dev/null 2>&1; then
      kill "$cleanup_watcher_pid" >/dev/null 2>&1 || true
      wait "$cleanup_watcher_pid" >/dev/null 2>&1 || true
    fi
    stop_local_services
  fi

  if owns_dev_lock; then
    rm -f "$dev_lock_file"
  fi

  exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "${HMUX_DEV_START_DB:-1}" != "0" ]]; then
  started_db=1
  claim_dev_lock
  start_cleanup_watcher
  bash "$ROOT_DIR/scripts/db-local.sh" up >/dev/null
  bash "$ROOT_DIR/scripts/db-local.sh" migrate
  start_db_watchdog
fi

redacted_database_url="postgres://${HMUX_DB_USER}:<redacted>@localhost:${HMUX_DB_PORT}/${HMUX_DB_NAME}"
cat <<EOF
hmux web dev
  HMUX_PORT=$HMUX_PORT
  HMUX_VM_API_BASE_URL=$HMUX_VM_API_BASE_URL
  DATABASE_URL=$redacted_database_url
  HMUX_WEB_SECRET_ENV_FILE=$HMUX_WEB_SECRET_ENV_FILE
  HMUX_WEB_EXTRA_SECRET_ENV_FILE=${HMUX_WEB_EXTRA_SECRET_ENV_FILE:-}
EOF

# This explicit opt-in is consumed by the billing guard. It is set only by
# this local development launcher, never by preview or production config.
export HMUX_LOCAL_DEV_PRO=1
next dev --port "$HMUX_PORT" &
next_pid=$!

set +e
wait "$next_pid"
status=$?
set -e
next_pid=""
exit "$status"
