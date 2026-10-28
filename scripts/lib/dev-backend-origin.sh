#!/bin/bash
# Resolve the shared private backend before packaging a tagged development app.
#
# HMUX_DEV_BACKEND_MODE selects the backend:
#   remote (default)  the shared backend, through scripts/dev-backend.sh (installed by
#                     hmuxterm-hq) or an explicit HMUX_DEV_BACKEND_URL.
#   local             the local dev origin passed as $3. For checkouts that were not
#                     created through hmuxterm-hq and cannot reach the shared backend.
hmux_resolve_tagged_backend() {
  local tag="$1" checkout="$2" local_origin="${3:-}" url="${HMUX_DEV_BACKEND_URL:-}"
  case "${HMUX_DEV_BACKEND_MODE:-remote}" in
    remote) ;;
    local)
      if [[ -n "$url" ]]; then
        echo 'HMUX_DEV_BACKEND_MODE=local cannot be combined with HMUX_DEV_BACKEND_URL.' >&2
        return 1
      fi
      if [[ -z "$local_origin" ]]; then
        echo 'HMUX_DEV_BACKEND_MODE=local needs a local dev origin.' >&2
        return 1
      fi
      printf '%s\n' "$local_origin"
      return 0
      ;;
    *)
      echo "Invalid HMUX_DEV_BACKEND_MODE '${HMUX_DEV_BACKEND_MODE}' (expected remote or local)." >&2
      return 1
      ;;
  esac
  if [[ -z "$url" ]]; then
    [[ -x "$checkout/scripts/dev-backend.sh" ]] || {
      echo 'Tagged development requires the shared GCP backend helper. Create this checkout through hmuxterm-hq.' >&2
      echo 'Without hmuxterm-hq access, set HMUX_DEV_BACKEND_MODE=local to build against the local dev origin.' >&2
      return 1
    }
    "$checkout/scripts/dev-backend.sh" start --tag "$tag" --checkout "$checkout" --transport direct >&2 || return 1
    url="$("$checkout/scripts/dev-backend.sh" url --tag "$tag")" || return 1
  fi
  case "$url" in
    https://hmux-dev-backend-1.tail137216.ts.net:*) ;;
    *) echo 'Development API URLs must use the shared Tailscale backend.' >&2; return 1 ;;
  esac
  local port="${url#https://hmux-dev-backend-1.tail137216.ts.net:}"
  port="${port%/}"
  [[ "$port" =~ ^[0-9]{4}$ && "$port" -ge 3800 && "$port" -le 4799 ]] || {
    echo 'Development backend URL has an invalid port or path.' >&2; return 1;
  }
  printf 'https://hmux-dev-backend-1.tail137216.ts.net:%s/\n' "$port"
}
