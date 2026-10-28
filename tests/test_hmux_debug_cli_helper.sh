#!/usr/bin/env bash
# Regression test: the tag-bound debug CLI helper scrubs ambient hmux env and
# routes commands through the tagged socket and tagged bundled CLI.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TAG="Debug_Helper.Test"
TAG_SLUG="debug-helper-test"
TAG_BUNDLE_ID="debug.helper.test"
SOCKET_PATH="/tmp/hmux-debug-${TAG_SLUG}.sock"
TMP_DIR="$(mktemp -d)"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
  rm -f "$SOCKET_PATH"
}
trap cleanup EXIT

FAKE_HOME="$TMP_DIR/home"
FAKE_CLI_DIR="$FAKE_HOME/Library/Developer/Xcode/DerivedData/hmux-${TAG_SLUG}/Build/Products/Debug/hmux DEV ${TAG_SLUG}.app/Contents/Resources/bin"
FAKE_CLI="$FAKE_CLI_DIR/hmux"
mkdir -p "$FAKE_CLI_DIR"
cat > "$FAKE_CLI" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "env" ]]; then
  env | sort
  exit 0
fi
printf 'fake hmux argv:'
printf ' %q' "$@"
printf '\n'
EOF
chmod +x "$FAKE_CLI"

rm -f "$SOCKET_PATH"
python3 - "$SOCKET_PATH" <<'PY' >/dev/null 2>&1 &
import os
import socket
import sys
import time

path = sys.argv[1]
try:
    os.unlink(path)
except FileNotFoundError:
    pass

sock = socket.socket(socket.AF_UNIX)
sock.bind(path)
sock.listen(1)
time.sleep(60)
PY
SERVER_PID="$!"

for _ in {1..100}; do
  if [[ -S "$SOCKET_PATH" ]]; then
    break
  fi
  sleep 0.05
done

if [[ ! -S "$SOCKET_PATH" ]]; then
  echo "FAIL: test socket was not created at $SOCKET_PATH"
  exit 1
fi

OUTPUT="$(
  HOME="$FAKE_HOME" \
  HMUX_TAG="$TAG" \
  HMUX_SOCKET="/tmp/main-hmux-legacy.sock" \
  HMUX_SOCKET_PATH="/tmp/main-hmux.sock" \
  HMUX_SOCKET_PASSWORD="main-secret" \
  HMUX_BUNDLE_ID="com.hmuxterm.app" \
  HMUX_BUNDLED_CLI_PATH="/Applications/hmux.app/Contents/Resources/bin/hmux" \
  HMUX_WORKSPACE_ID="main-workspace" \
  HMUX_TAB_ID="main-tab" \
  HMUX_SURFACE_ID="main-surface" \
  HMUX_PANEL_ID="main-panel" \
  HMUXD_UNIX_PATH="/tmp/main-hmuxd.sock" \
  HMUX_DEBUG_LOG="/tmp/main-hmux.log" \
  "$ROOT_DIR/scripts/hmux-debug-cli.sh" env
)"

require_line() {
  local expected="$1"
  if ! grep -Fxq "$expected" <<<"$OUTPUT"; then
    echo "FAIL: expected env line not found: $expected"
    echo "$OUTPUT"
    exit 1
  fi
}

reject_prefix() {
  local prefix="$1"
  if grep -Eq "^${prefix}=" <<<"$OUTPUT"; then
    echo "FAIL: unexpected env line with prefix: $prefix"
    echo "$OUTPUT"
    exit 1
  fi
}

require_line "HMUX_SOCKET_PATH=$SOCKET_PATH"
require_line "HMUX_TAG=$TAG_SLUG"
require_line "HMUX_BUNDLE_ID=com.hmuxterm.app.debug.${TAG_BUNDLE_ID}"
require_line "HMUX_BUNDLED_CLI_PATH=$FAKE_CLI"

reject_prefix "HMUX_SOCKET"
reject_prefix "HMUX_SOCKET_PASSWORD"
reject_prefix "HMUX_WORKSPACE_ID"
reject_prefix "HMUX_TAB_ID"
reject_prefix "HMUX_SURFACE_ID"
reject_prefix "HMUX_PANEL_ID"
reject_prefix "HMUXD_UNIX_PATH"
reject_prefix "HMUX_DEBUG_LOG"

# A build restored by publish-hq lives in the HQ Tag Opener cache, not DerivedData.
CACHED_CLI_DIR="$FAKE_HOME/Library/Application Support/hmux/tag-app-cache/hmux-${TAG_SLUG}/hmux DEV ${TAG_SLUG}.app/Contents/Resources/bin"
mkdir -p "$CACHED_CLI_DIR"
cp "$FAKE_CLI" "$CACHED_CLI_DIR/hmux"
rm -rf "$FAKE_HOME/Library/Developer/Xcode/DerivedData"
OUTPUT="$(HOME="$FAKE_HOME" HMUX_TAG="$TAG" "$ROOT_DIR/scripts/hmux-debug-cli.sh" env)"
require_line "HMUX_BUNDLED_CLI_PATH=$CACHED_CLI_DIR/hmux"

echo "PASS: hmux-debug-cli.sh routes through the tagged CLI/socket and scrubs ambient hmux env"
