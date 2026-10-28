# hmux Cloud devbox agent sign-in mode (/etc/hmux/agent-auth.sh). POSIX sh:
# sourced by the agent launchers (/etc/hmux/claude, /etc/hmux/codex,
# /etc/hmux/opencode) at every launch and by the in-VM `cr use` command to
# report the mode.
#
# Each agent (claude, codex, opencode) on a machine runs in one of two modes:
#   team  the team's CodeRouter accounts, through the machine's TLS edge
#         (zero setup; the launcher adds the CodeRouter configuration)
#   own   the user's own sign-in to the agent (Claude Code /login, codex
#         login, opencode auth login); the launcher adds no CodeRouter
#         configuration and drops the model-plane env, so nothing outranks
#         that sign-in and no own credential is sent to CodeRouter
#
# HMUX_<AGENT>_AUTH=team|own in the environment pins one launch (automation,
# image verification). Otherwise the choice lives in
# ~/.config/hmux/agent-auth/<agent> ("team" or "own"), written by `cr use`.
# Without one, an own sign-in to that agent on the machine counts as choosing
# own; otherwise team when the team has an account for the agent, else own,
# so the agent shows its normal sign-in instead of a CodeRouter refusal.

# The public placeholder every guest sends (VM_PLACEHOLDER_API_KEY in
# services/coderouter/vmGuestEnv.ts); the machine's edge swaps in the real
# credential. The only key this file ever sends anywhere.
hmux_aa_placeholder=hmux-vm-edge-placeholder

# The file holding <agent>'s explicit choice.
hmux_agent_auth_file() {
  printf '%s/.config/hmux/agent-auth/%s' "${HOME:-/root}" "$1"
}

# Prints <agent>'s explicit choice (team or own), or nothing.
hmux_agent_auth_choice() {
  hmux_aa_file=$(hmux_agent_auth_file "$1")
  [ -f "$hmux_aa_file" ] || return 0
  hmux_aa_value=$(head -n 1 "$hmux_aa_file" 2>/dev/null | tr -d '[:space:]')
  case "$hmux_aa_value" in team|own) printf '%s' "$hmux_aa_value" ;; esac
}

# 0 when <agent> has its own sign-in on this machine.
#   claude    a /login session in its credentials file, or a long-lived
#             token from `claude setup-token`
#   codex     `codex login` (ChatGPT tokens or an API key) in auth.json, or
#             CODEX_API_KEY
#   opencode  any provider credential from `opencode auth login`
hmux_agent_has_own_login() {
  case "$1" in
    claude)
      [ -n "${CLAUDE_CODE_OAUTH_TOKEN-}" ] && return 0
      hmux_aa_login="${CLAUDE_CONFIG_DIR:-${HOME:-/root}/.claude}/.credentials.json"
      [ -f "$hmux_aa_login" ] && grep -q '"claudeAiOauth"' "$hmux_aa_login" 2>/dev/null
      ;;
    codex)
      [ -n "${CODEX_API_KEY-}" ] && return 0
      hmux_aa_login="${CODEX_HOME:-${HOME:-/root}/.codex}/auth.json"
      [ -f "$hmux_aa_login" ] && python3 -c '
import json, sys
try:
    auth = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
tokens = auth.get("tokens") if isinstance(auth, dict) else None
key = auth.get("OPENAI_API_KEY") if isinstance(auth, dict) else None
sys.exit(0 if (isinstance(tokens, dict) and tokens) or (isinstance(key, str) and key) else 1)
' "$hmux_aa_login" 2>/dev/null
      ;;
    opencode)
      hmux_aa_login="${XDG_DATA_HOME:-${HOME:-/root}/.local/share}/opencode/auth.json"
      [ -f "$hmux_aa_login" ] && python3 -c '
import json, sys
try:
    auth = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
sys.exit(0 if isinstance(auth, dict) and auth else 1)
' "$hmux_aa_login" 2>/dev/null
      ;;
    *) return 1 ;;
  esac
}

# Whether the team's CodeRouter can serve <agent> on this machine:
# 0 it has an account for the agent, 1 it has none, 2 no answer (no model
# plane, an error or unreadable reply, a server without the endpoint),
# 3 CodeRouter is unreachable from this machine (its address does not
# resolve or connect), so team mode could not work either.
# One GET /api/coderouter/agent-access answers every agent; the answer is
# reused for 60 s (~/.cache/hmux/agent-access) so back-to-back launches,
# including headless runs, pay for the check at most once a minute. `cr use`
# clears it, so its report and the next launch are current.
hmux_agent_team_access() {
  case "$1" in claude) hmux_aa_field=2 ;; codex) hmux_aa_field=3 ;; opencode) hmux_aa_field=4 ;; *) return 2 ;; esac
  hmux_aa_cache="${HOME:-/root}/.cache/hmux/agent-access"
  hmux_aa_now=$(date +%s 2>/dev/null) || hmux_aa_now=0
  hmux_aa_line=""
  if [ -f "$hmux_aa_cache" ]; then
    hmux_aa_line=$(head -n 1 "$hmux_aa_cache" 2>/dev/null) || hmux_aa_line=""
    case "$hmux_aa_line" in
      *[!0-9\ ]*|'') hmux_aa_line="" ;;
      *)
        hmux_aa_at=${hmux_aa_line%% *}
        # A corrupt epoch longer than any real one would overflow dash's
        # arithmetic; treat it as no answer.
        case "$hmux_aa_at" in ?????????????*) hmux_aa_at=0 ;; esac
        if [ "$hmux_aa_now" -lt "$hmux_aa_at" ] || [ $((hmux_aa_now - hmux_aa_at)) -ge 60 ]; then hmux_aa_line=""; fi
        ;;
    esac
  fi
  if [ -z "$hmux_aa_line" ]; then
    hmux_aa_line="$hmux_aa_now $(hmux_agent_team_access_fetch)"
    { mkdir -p "${hmux_aa_cache%/*}" && printf '%s\n' "$hmux_aa_line" > "$hmux_aa_cache"; } 2>/dev/null || :
  fi
  hmux_aa_code=$(printf '%s\n' "$hmux_aa_line" | cut -d ' ' -f "$hmux_aa_field")
  case "$hmux_aa_code" in 0|1|3) return "$hmux_aa_code" ;; *) return 2 ;; esac
}

# Prints "<claude> <codex> <opencode>" codes (0 account, 1 none, 2 unknown,
# 3 unreachable).
hmux_agent_team_access_fetch() {
  hmux_aa_origin="${HMUX_CODEROUTER_URL-}"
  case "$hmux_aa_origin" in https://*) ;; *) echo "2 2 2"; return 0 ;; esac
  command -v curl >/dev/null 2>&1 || { echo "2 2 2"; return 0; }
  set -- -fsS --connect-timeout 2 --max-time 5 -H "authorization: Bearer $hmux_aa_placeholder" -H 'accept: application/json'
  if [ -f /usr/local/share/ca-certificates/freestyle-tls.crt ]; then
    set -- "$@" --cacert /usr/local/share/ca-certificates/freestyle-tls.crt
  fi
  if hmux_aa_body=$(curl "$@" "${hmux_aa_origin%/}/api/coderouter/agent-access" 2>/dev/null); then :; else
    # 6 the name does not resolve, 7 nothing accepts the connection: no
    # request through CodeRouter can succeed. Anything else may be passing.
    case "$?" in 6|7) echo "3 3 3"; return 0 ;; esac
  fi
  printf '%s' "$hmux_aa_body" | python3 -c '
import json, sys
try:
    agents = json.load(sys.stdin)["agents"]
except Exception:
    agents = {}
def code(name):
    value = agents.get(name) if isinstance(agents, dict) else None
    return "0" if value is True else "1" if value is False else "2"
print(code("claude"), code("codex"), code("opencode"))
' 2>/dev/null || echo "2 2 2"
}

# Sets hmux_agent_auth_mode (team|own) and hmux_agent_auth_reason for <agent>:
#   env             HMUX_<AGENT>_AUTH pins this launch
#   chosen          `cr use` recorded the mode
#   login           no choice; the agent has its own sign-in here
#   team-account    no choice or sign-in; the team has an account for it
#   no-team-account no choice or sign-in; the team has none
#   team-unreachable no choice or sign-in; CodeRouter cannot be reached from
#                   this machine, so team mode could not work
#   team-unknown    no choice or sign-in; the account check got no answer,
#                   so the long-standing default (team) applies
hmux_agent_auth_resolve() {
  eval "hmux_agent_auth_mode=\${HMUX_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')_AUTH-}"
  case "$hmux_agent_auth_mode" in
    team|own) hmux_agent_auth_reason=env; return 0 ;;
  esac
  hmux_agent_auth_mode=$(hmux_agent_auth_choice "$1")
  if [ -n "$hmux_agent_auth_mode" ]; then
    hmux_agent_auth_reason=chosen
    return 0
  fi
  if hmux_agent_has_own_login "$1"; then
    hmux_agent_auth_mode=own
    hmux_agent_auth_reason=login
    return 0
  fi
  if hmux_agent_team_access "$1"; then hmux_aa_rc=0; else hmux_aa_rc=$?; fi
  case "$hmux_aa_rc" in
    0) hmux_agent_auth_mode=team; hmux_agent_auth_reason=team-account ;;
    1) hmux_agent_auth_mode=own; hmux_agent_auth_reason=no-team-account ;;
    3) hmux_agent_auth_mode=own; hmux_agent_auth_reason=team-unreachable ;;
    *) hmux_agent_auth_mode=team; hmux_agent_auth_reason=team-unknown ;;
  esac
}

# Own mode: drop every model-plane value from this launch's env, never a
# user-set endpoint or key. The values are the model plane's when they are
# the CodeRouter origin or the public placeholder.
hmux_agent_drop_model_plane_env() {
  hmux_aa_origin="${HMUX_CODEROUTER_URL-}"
  hmux_aa_origin="${hmux_aa_origin%/}"
  hmux_aa_openai="${OPENAI_BASE_URL-}"
  if [ -n "${ANTHROPIC_BASE_URL-}" ] && { [ "$ANTHROPIC_BASE_URL" = "${HMUX_CLAUDE_TEAM_BASE_URL-}" ] || [ "${ANTHROPIC_BASE_URL%/}" = "$hmux_aa_origin" ]; }; then
    unset ANTHROPIC_BASE_URL
  fi
  if [ "${ANTHROPIC_API_KEY-}" = "$hmux_aa_placeholder" ]; then unset ANTHROPIC_API_KEY; fi
  if [ -n "$hmux_aa_origin" ] && [ "${hmux_aa_openai%/}" = "$hmux_aa_origin/v1" ]; then unset OPENAI_BASE_URL; fi
  if [ "${OPENAI_API_KEY-}" = "$hmux_aa_placeholder" ]; then unset OPENAI_API_KEY; fi
  # The usage headers name the hmux workspace and terminal; they mean nothing
  # to any other endpoint.
  if [ -n "${ANTHROPIC_CUSTOM_HEADERS-}" ] && ! printf '%s\n' "$ANTHROPIC_CUSTOM_HEADERS" | grep -qv '^x-hmux-'; then
    unset ANTHROPIC_CUSTOM_HEADERS
  fi
}

# Shapes the environment of a claude launch for its mode. team: the
# model-plane pair agent-config.sh set aside, unless the user exported their
# own ANTHROPIC_BASE_URL/ANTHROPIC_API_KEY (those always win). own: no
# CodeRouter env at all.
hmux_claude_apply_auth_mode() {
  hmux_agent_auth_resolve claude
  if [ "$hmux_agent_auth_mode" = team ]; then
    if [ -z "${ANTHROPIC_BASE_URL-}" ] && [ -z "${ANTHROPIC_API_KEY-}" ] && [ -n "${HMUX_CLAUDE_TEAM_BASE_URL-}" ]; then
      ANTHROPIC_BASE_URL=$HMUX_CLAUDE_TEAM_BASE_URL
      ANTHROPIC_API_KEY=${HMUX_CLAUDE_TEAM_API_KEY-}
      export ANTHROPIC_BASE_URL ANTHROPIC_API_KEY
    fi
    return 0
  fi
  hmux_agent_drop_model_plane_env
}

# codex reads its provider from ~/.codex/config.toml, which agent-config.sh
# generates with model_provider = "hmux" (CodeRouter). Own mode sets
# hmux_codex_own_provider=1: the launcher then starts codex with
# -c model_provider="openai", the built-in provider that uses `codex login`.
# Only a config hmux generated is overridden; a user's own provider choice is
# left alone.
hmux_codex_apply_auth_mode() {
  hmux_codex_own_provider=0
  hmux_agent_auth_resolve codex
  [ "$hmux_agent_auth_mode" = own ] || return 0
  hmux_agent_drop_model_plane_env
  if grep -qx 'model_provider = "hmux"' "${CODEX_HOME:-${HOME:-/root}/.codex}/config.toml" 2>/dev/null; then
    hmux_codex_own_provider=1
  fi
}

# opencode sends a key from `opencode auth login` to whatever
# OPENAI_BASE_URL/ANTHROPIC_BASE_URL name. Team mode layers the CodeRouter
# providers on the user's own configuration for this launch (the launcher
# sets OPENCODE_CONFIG); each carries its own CodeRouter baseURL, so the
# model-plane endpoints are dropped there too and an own provider still
# reaches its own service. Only OPENAI_API_KEY stays: the team providers read
# the placeholder from it. Own mode adds nothing and drops the whole plane.
hmux_opencode_apply_auth_mode() {
  hmux_agent_auth_resolve opencode
  if [ "$hmux_agent_auth_mode" = team ]; then
    hmux_ao_key=${OPENAI_API_KEY-}
    hmux_agent_drop_model_plane_env
    if [ "$hmux_ao_key" = "$hmux_aa_placeholder" ]; then
      OPENAI_API_KEY=$hmux_ao_key
      export OPENAI_API_KEY
    fi
    return 0
  fi
  hmux_agent_drop_model_plane_env
}
