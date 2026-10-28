#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" || -z "${2:-}" ]]; then
  printf 'Usage: %s <url> <surface>\n' "${0##*/}" >&2
  exit 2
fi

URL="$1"
SURFACE="$2"

hmux browser --surface "$SURFACE" goto "$URL"
hmux browser --surface "$SURFACE" get url
hmux browser --surface "$SURFACE" wait --load-state complete --timeout-ms 15000
hmux browser --surface "$SURFACE" snapshot --interactive

echo "Now run fill/click commands using refs from the snapshot above."
