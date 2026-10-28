#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${HMUX_TAG:-}" ]]; then
  cat >&2 <<'EOF'
HMUX_TAG is required.

Usage:
  HMUX_TAG=<tag> scripts/hmux-debug-cli.sh <hmux-command> [args...]

Example:
  HMUX_TAG=codext scripts/hmux-debug-cli.sh list-workspaces
EOF
  exit 2
fi

if [[ ! "$HMUX_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid HMUX_TAG: $HMUX_TAG" >&2
  exit 2
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: HMUX_TAG=$HMUX_TAG scripts/hmux-debug-cli.sh <hmux-command> [args...]" >&2
  exit 2
fi

sanitize_bundle() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\.+//; s/\.+$//; s/\.+/./g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  printf '%s\n' "$cleaned"
}

sanitize_path() {
  local raw="$1"
  local cleaned
  cleaned="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  printf '%s\n' "$cleaned"
}

tag_slug="$(sanitize_path "$HMUX_TAG")"
tag_bundle_id="$(sanitize_bundle "$HMUX_TAG")"

socket_path="/tmp/hmux-debug-${tag_slug}.sock"
if [[ ! -S "$socket_path" ]]; then
  cat >&2 <<EOF
Tagged hmux socket not found:
  $socket_path

Launch the tagged app first:
  ./scripts/reload.sh --tag $HMUX_TAG --launch
EOF
  exit 1
fi

# Same default as reload.sh: a checkout that exports HMUX_DERIVED_DATA builds every tag there.
derived_data="${HMUX_DERIVED_DATA:-${HOME}/Library/Developer/Xcode/DerivedData/hmux-${tag_slug}}"
if [[ "$derived_data" != /* ]]; then
  echo "error: HMUX_DERIVED_DATA must be an absolute path, got '$derived_data'" >&2
  exit 1
fi
cli_path="${derived_data}/Build/Products/Debug/hmux DEV ${tag_slug}.app/Contents/Resources/bin/hmux"
# reload.sh --release builds the same tagged app under Build/Products/Release.
release_cli_path="${derived_data}/Build/Products/Release/hmux DEV ${tag_slug}.app/Contents/Resources/bin/hmux"
if [[ ! -x "$cli_path" && -x "$release_cli_path" ]]; then
  cli_path="$release_cli_path"
fi
# A fleet build restored with `hmux-ci publish-hq` lives in the HQ Tag Opener cache.
cached_cli_path="${HOME}/Library/Application Support/hmux/tag-app-cache/hmux-${tag_slug}/hmux DEV ${tag_slug}.app/Contents/Resources/bin/hmux"
if [[ ! -x "$cli_path" && -x "$cached_cli_path" ]]; then
  cli_path="$cached_cli_path"
fi
if [[ ! -x "$cli_path" ]]; then
  cat >&2 <<EOF
Tagged hmux CLI not found:
  $cli_path
  $cached_cli_path

Build the tagged app first:
  ./scripts/reload.sh --tag $HMUX_TAG
EOF
  exit 1
fi

unset HMUX_SOCKET
unset HMUX_SOCKET_PASSWORD
unset HMUX_WORKSPACE_ID
unset HMUX_SURFACE_ID
unset HMUX_TAB_ID
unset HMUX_PANEL_ID
unset HMUXD_UNIX_PATH
unset HMUX_DEBUG_LOG
export HMUX_SOCKET_PATH="$socket_path"
export HMUX_TAG="$tag_slug"
export HMUX_BUNDLE_ID="com.hmuxterm.app.debug.${tag_bundle_id}"
export HMUX_BUNDLED_CLI_PATH="$cli_path"
exec "$cli_path" "$@"
