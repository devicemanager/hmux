#!/usr/bin/env bash
# Loads .env-local (see .env-local.template) for the local-only build scripts
# and derives their bundle IDs. Source it; it sets variables and returns.
#
# Values already in the environment win over the file, so a one-off run can
# override a single setting: HMUX_LOCAL_MAC_INSTALL_DIR= scripts/...

hmux_local_only_load_env() {
  local repo_root="$1"
  local env_file="${HMUX_LOCAL_ENV_FILE:-$repo_root/.env-local}"
  if [[ ! -f "$env_file" ]]; then
    echo "error: $env_file not found. Copy .env-local.template to .env-local and fill it in." >&2
    return 1
  fi
  local line key
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)= ]] || continue
    key="${BASH_REMATCH[1]}"
    # Keep a value the caller already exported.
    [[ -n "${!key+set}" ]] && continue
    eval "export $line"
  done < "$env_file"

  : "${HMUX_LOCAL_TEAM_ID:?set HMUX_LOCAL_TEAM_ID in $env_file}"
  if [[ -z "${HMUX_LOCAL_IOS_BUNDLE_ID:-}" || -z "${HMUX_LOCAL_MAC_BUNDLE_ID:-}" ]]; then
    : "${HMUX_LOCAL_BUNDLE_PREFIX:?set HMUX_LOCAL_BUNDLE_PREFIX (or both bundle IDs) in $env_file}"
  fi
  export HMUX_LOCAL_IOS_BUNDLE_ID="${HMUX_LOCAL_IOS_BUNDLE_ID:-$HMUX_LOCAL_BUNDLE_PREFIX.hmux}"
  export HMUX_LOCAL_MAC_BUNDLE_ID="${HMUX_LOCAL_MAC_BUNDLE_ID:-$HMUX_LOCAL_BUNDLE_PREFIX.hmux.mac}"

  local id
  for id in "$HMUX_LOCAL_IOS_BUNDLE_ID" "$HMUX_LOCAL_MAC_BUNDLE_ID"; do
    case "$id" in
      com.cmuxterm.*|dev.cmux.*|ai.manaflow.*)
        echo "error: bundle ID $id belongs to the official cmux apps; use your own prefix" >&2
        return 1
        ;;
    esac
  done

  # GhosttyKit's build takes zig from PATH; put the configured one first.
  if [[ -n "${HMUX_ZIG:-}" ]]; then
    export PATH="$(dirname "$HMUX_ZIG"):$PATH"
  fi
}
