#!/bin/bash
# Shared lock ownership for remote-tmux fuzz drivers. Callers source this file
# and register `hmux_fuzz_lock_release` from their existing EXIT cleanup.

hmux_fuzz_lock_acquire() {
  local tmp_root=$1 holder attempts=0
  HMUX_FUZZ_LOCK_DIR="${HMUX_FUZZ_LOCK_DIR:-${tmp_root%/}/hmux-fuzz-marathon.lock}"
  while ! mkdir "$HMUX_FUZZ_LOCK_DIR" 2>/dev/null; do
    if [ -L "$HMUX_FUZZ_LOCK_DIR" ] || [ ! -d "$HMUX_FUZZ_LOCK_DIR" ] \
       || [ ! -O "$HMUX_FUZZ_LOCK_DIR" ]; then
      echo "fuzz lock exists but is not an owned directory — refusing to start" >&2
      return 96
    fi
    holder="$(cat "$HMUX_FUZZ_LOCK_DIR/pid" 2>/dev/null)"
    case "$holder" in ''|*[!0-9]*) holder="" ;; esac
    if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
      echo "another fuzz driver (pid $holder) is running — refusing to start"
      return 96
    fi
    if [ "$attempts" -ge 1 ]; then
      echo "could not atomically acquire fuzz lock" >&2
      return 96
    fi
    # Stale takeover removes only this protocol's private entries. `rmdir`
    # refuses a caller-supplied directory containing anything else.
    rm -f -- "$HMUX_FUZZ_LOCK_DIR/pid" "$HMUX_FUZZ_LOCK_DIR/token"
    if ! rmdir -- "$HMUX_FUZZ_LOCK_DIR" 2>/dev/null; then
      echo "owned stale fuzz lock contains unexpected entries — refusing to remove it" >&2
      return 96
    fi
    attempts=$((attempts + 1))
  done

  HMUX_FUZZ_LOCK_TOKEN="$$.$RANDOM.$(date +%s)"
  if ! printf '%s\n' "$$" > "$HMUX_FUZZ_LOCK_DIR/pid" \
     || ! printf '%s\n' "$HMUX_FUZZ_LOCK_TOKEN" > "$HMUX_FUZZ_LOCK_DIR/token"; then
    rm -f -- "$HMUX_FUZZ_LOCK_DIR/pid" "$HMUX_FUZZ_LOCK_DIR/token"
    rmdir -- "$HMUX_FUZZ_LOCK_DIR" 2>/dev/null
    echo "could not initialize fuzz lock" >&2
    return 96
  fi
  HMUX_FUZZ_LOCK_OWNED=1
  export HMUX_FUZZ_LOCK_HELD=1 HMUX_FUZZ_LOCK_DIR HMUX_FUZZ_LOCK_TOKEN
}

hmux_fuzz_lock_validate_inherited() {
  local holder
  if [ -z "${HMUX_FUZZ_LOCK_DIR:-}" ] || [ -z "${HMUX_FUZZ_LOCK_TOKEN:-}" ]; then
    echo "inherited fuzz lock is missing or invalid — refusing to start" >&2
    return 96
  fi
  if [ -L "$HMUX_FUZZ_LOCK_DIR" ] || [ ! -d "$HMUX_FUZZ_LOCK_DIR" ] \
     || [ ! -O "$HMUX_FUZZ_LOCK_DIR" ] \
     || [ "$(cat "$HMUX_FUZZ_LOCK_DIR/token" 2>/dev/null)" != "$HMUX_FUZZ_LOCK_TOKEN" ]; then
    echo "inherited fuzz lock is missing or invalid — refusing to start" >&2
    return 96
  fi
  holder="$(cat "$HMUX_FUZZ_LOCK_DIR/pid" 2>/dev/null)"
  if [ "$holder" != "$PPID" ] || ! kill -0 "$holder" 2>/dev/null; then
    echo "inherited fuzz lock is missing or invalid — refusing to start" >&2
    return 96
  fi
}

hmux_fuzz_lock_release() {
  [ "${HMUX_FUZZ_LOCK_OWNED:-0}" = 1 ] || return 0
  if [ ! -L "$HMUX_FUZZ_LOCK_DIR" ] && [ -O "$HMUX_FUZZ_LOCK_DIR" ] \
     && [ "$(cat "$HMUX_FUZZ_LOCK_DIR/token" 2>/dev/null)" = "$HMUX_FUZZ_LOCK_TOKEN" ]; then
    rm -f -- "$HMUX_FUZZ_LOCK_DIR/pid" "$HMUX_FUZZ_LOCK_DIR/token"
    rmdir -- "$HMUX_FUZZ_LOCK_DIR" 2>/dev/null || true
  fi
  HMUX_FUZZ_LOCK_OWNED=0
}
