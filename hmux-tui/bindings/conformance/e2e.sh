#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGS=("$@")
if [[ -n "${HMUX_TUI_BIN:-}" ]]; then
  ARGS+=(--hmux-tui-bin "$HMUX_TUI_BIN")
fi
exec python3 "$SCRIPT_DIR/runner.py" "${ARGS[@]}"
