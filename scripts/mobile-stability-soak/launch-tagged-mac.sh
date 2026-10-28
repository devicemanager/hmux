#!/usr/bin/env bash
set -euo pipefail

tag="${HMUX_TAG:-swmob}"
repo="${HMUX_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
app="${HMUX_SWAPP:-$HOME/Library/Developer/Xcode/DerivedData/hmux-${tag}/Build/Products/Debug/hmux DEV ${tag}.app}"
port="${HMUX_PORT:-9300}"
port_range="${HMUX_PORT_RANGE:-10}"
port_end="${HMUX_PORT_END:-$((port + port_range - 1))}"
dev_origin="${HMUX_DEV_ORIGIN:-http://localhost:${port}}"
bin="$app/Contents/MacOS/hmux DEV"
tag_bundle_id="$(printf '%s' "$tag" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\.+//; s/\.+$//; s/\.+/./g')"
if [[ -z "$tag_bundle_id" ]]; then
  tag_bundle_id="agent"
fi

if [[ ! -x "$bin" ]]; then
  echo "missing tagged app binary: $bin" >&2
  exit 1
fi

exec env \
  HMUX_BUNDLE_ID="com.hmuxterm.app.debug.${tag_bundle_id}" \
  HMUX_SOCKET_ENABLE=1 \
  HMUX_SOCKET_MODE=allowAll \
  HMUX_SOCKET_PATH="/tmp/hmux-debug-${tag}.sock" \
  HMUXD_UNIX_PATH="$HOME/Library/Application Support/hmux/hmuxd-dev-${tag}.sock" \
  HMUX_DEBUG_LOG="/tmp/hmux-debug-${tag}.log" \
  HMUX_API_BASE_URL="$dev_origin" \
  HMUX_AUTH_WWW_ORIGIN="$dev_origin" \
  HMUX_VM_API_BASE_URL="$dev_origin" \
  HMUX_PORT="$port" \
  HMUX_PORT_RANGE="$port_range" \
  HMUX_PORT_END="$port_end" \
  PORT="$port" \
  HMUX_BUNDLED_CLI_PATH="$app/Contents/Resources/bin/hmux" \
  HMUX_SHELL_INTEGRATION_DIR="$app/Contents/Resources/shell-integration" \
  HMUX_REMOTE_DAEMON_ALLOW_LOCAL_BUILD=1 \
  HMUXTERM_REPO_ROOT="$repo" \
  "$bin"
