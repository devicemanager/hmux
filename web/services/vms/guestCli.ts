// The in-VM `hmux` CLI: a POSIX shim over the machine's own hmux-tui binary.
//
// Every hmux Cloud machine runs the hmux-tui daemon (session "cloud"). This
// adapter keeps the shared hmux command family while mapping local resource
// commands to hmux-tui and cloud/agent commands to the machine's TLS edge.
// `hmux vm …` talks to OTHER machines through hmux-remote links the Mac
// granted with `hmux vm link <src> <dst>` (peer route files in ~/.hmux/peers).
// The adapter is provider-agnostic: it needs only the daemon binary, route
// files, and the standard CodeRouter environment; no provider SDK or Stack
// credential is copied into the guest.
//
// Beyond the transport verbs it carries the agent primitives that must mean
// the same thing on the Mac and inside a machine: `layout export|apply` (a
// workspace as the declarative document `hmux new-workspace --layout` and
// `hmux layout open` accept), `env set|ls|rm` (the machine env every hmux
// shell and agent sources), and the Mac's terminal verbs (`send`, `send-key`,
// `read-screen`, `terminal send|read|wait|close`) — locally and toward
// linked peers (`hmux vm <verb> <peer> …`). The Mac's `hmux vm layout|env …`
// run these same functions over `vm exec`, so there is one implementation.
// `env receive` and `file receive` are the receiving ends of the link-typed
// handshakes (`hmux vm env set`, `hmux vm push --secret` / peer `vm push`);
// `vm agent … --wait --output` turns a peer's durable agent terminal into a
// blocking call with the agent's exit code and stream.
//
// Reflection (`hmux whoami`, `hmux reflect`, peer discovery) reads the control
// plane's `/api/vm/reflection/*` through the model-plane alias: the edge injects
// the machine's VM-bound route token, so the machine learns who it is without
// holding any credential — exe.dev's Reflection integration is the model.
//
// Installed by the driver at create/heal (see freestyle.ts bootstrap), so it
// reaches machines created from any existing snapshot. This driver-installed
// adapter is the sole source; image bakes keep their promoted CLI until healing.

import { GUEST_HMUX_ADAPTER_PATH, guestCliDistributionCommand } from "./guestCliDistribution";
import { GUEST_CODEROUTER_SHELL, GUEST_CODEROUTER_USE_SHELL } from "./guestCoderouterCli";
import { GUEST_HMUX_MESSAGE_SHELL } from "./guestCliMessages";
import { GUEST_HMUX_TOPOLOGY_SHELL } from "./guestTopologyCli";
import { GUEST_BROWSER_OPENER_PATH, guestBrowserInstallCommand } from "./guestBrowser";

export const GUEST_HMUX_SHIM_PATH = GUEST_HMUX_ADAPTER_PATH;

export const GUEST_HMUX_SHIM = `#!/bin/sh
# hmux — in-VM CLI. One grammar, the same as on a Mac:
#   hmux <verb> …               THIS machine's session (hmux-tui, session "cloud")
#   hmux vm <verb> <machine> …  ANOTHER machine of the same owner, over a peer link
#   hmux vm ls                  the owner's machines, this one marked *
#   hmux self [<path>]          who am I (reflection; aliases whoami, reflect)
set -eu

${GUEST_HMUX_MESSAGE_SHELL}

if [ "\${1:-}" = open-url ]; then
  shift
  exec ${GUEST_BROWSER_OPENER_PATH} "$@"
fi

# The daemon binary lives under the daemon's home, which depends on the image
# layout (root daemon: /root; layout-aware bakes: the hmux user's home or the
# persistent-volume backing path, with /usr/local/bin/hmux-tui symlinked to it).
# Try the stable symlink first, then every known home.
hmux_tui_default() {
  for candidate in /usr/local/bin/hmux-tui /root/.hmux/bin/hmux-tui "\${HOME:-/root}/.hmux/bin/hmux-tui" \\
    /home/hmux/.hmux/bin/hmux-tui /hmux/home/.hmux/bin/hmux-tui; do
    if [ -x "\$candidate" ]; then printf '%s' "\$candidate"; return 0; fi
  done
  command -v hmux-tui 2>/dev/null || printf '%s' /root/.hmux/bin/hmux-tui
}
HMUX_TUI_BIN="\${HMUX_TUI_BIN:-\$(hmux_tui_default)}"
HMUX_GUEST_HOME="\${HMUX_GUEST_HOME:-\${HOME:-/root}/.hmux}"
PEERS_DIR="\$HMUX_GUEST_HOME/peers"
LINKS_DIR="\$HMUX_GUEST_HOME/peer-links"
LOCAL_SESSION="\${HMUX_TUI_SESSION:-cloud}"
# Session names are user input when the shim is reused outside the baked image.
# Keep them in the JSON/status output safe and deterministic.
case "\$LOCAL_SESSION" in
  ''|*[!A-Za-z0-9._-]*) LOCAL_SESSION=cloud ;;
esac

die() { printf '%s\\n' "hmux: \$1" >&2; exit "\${2:-1}"; }
die_message() {
  hmux_error_status="\$1"; shift
  printf 'hmux: ' >&2
  hmux_message "\$@" >&2
  exit "\$hmux_error_status"
}
# A warning never changes the exit code; \`layout apply\` also collects them for
# its JSON summary (hmux_la_scratch is set only while an apply is running).
warn() {
  printf '%s\\n' "hmux: warning: \$1" >&2
  if [ -n "\${hmux_la_scratch:-}" ] && [ -d "\$hmux_la_scratch" ]; then printf '%s\\n' "\$1" >> "\$hmux_la_scratch/warnings"; fi
  return 0
}

# Identity, discovery, and help come from the control plane or this file, so
# they answer while hmux-tui is still installing (the bootstrap shim's
# contract); every other verb needs the daemon.
case "\${1:-}:\${2:-}:\${3:-}" in
  vm:workspace:help|vm:workspace:--help|vm:workspace:-h|vm:pane:help|vm:pane:--help|vm:pane:-h|vm:tab:help|vm:tab:--help|vm:tab:-h)
    hmux_message topologyHelp; exit 0 ;;
  vm:terminal:help|vm:terminal:--help|vm:terminal:-h)
    hmux_message terminalHelp; exit 0 ;;
esac
case "\${1:-}:\${2:-}" in
  workspace:help|workspace:--help|workspace:-h|workspace:|pane:help|pane:--help|pane:-h|pane:|tab:help|tab:--help|tab:-h|tab:|terminal:help|terminal:--help|terminal:-h) ;;
  self:*|whoami:*|reflect:*|reflection:*|vm:ls|vm:list|vm:peers|vm:links|vm:help|vm:--help|vm:-h|vm:|:*|help:*|--help:*|-h:*|--version:*|-V:*) ;;
  *) [ -x "\$HMUX_TUI_BIN" ] || die_message 1 missingDaemon "\$HMUX_TUI_BIN" ;;
esac

# One routing target for every verb: this machine's session, or — after
# use_peer — a linked peer's headless-link socket. tui() prepends it, so the
# same functions (terminal, layout, env, workspace) serve both without a copy.
TARGET_FLAG=--session
TARGET_VALUE="\$LOCAL_SESSION"
TARGET_LABEL=local
tui() { "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" "\$@"; }
use_peer() {
  hmux_peer_sock="\$(ensure_link "\$1")"
  TARGET_FLAG=--socket
  TARGET_VALUE="\$hmux_peer_sock"
  TARGET_LABEL="\$1"
}

guest_usage() {
  hmux_message help
}

load_model_env() {
  if [ -f "\$HOME/.config/hmux/model-plane.env" ]; then
    . "\$HOME/.config/hmux/model-plane.env"
  elif [ -f /etc/hmux/model-plane.env ]; then
    . /etc/hmux/model-plane.env
  fi
  # A route token is an edge-held capability, never a guest credential. Refuse
  # a manually copied token instead of making it look like the supported path.
  for hmux_value in "\${OPENAI_API_KEY:-}" "\${ANTHROPIC_API_KEY:-}" "\${HMUX_CODEROUTER_URL:-}"; do
    case "\$hmux_value" in
      *crt_*) die_message 2 routeToken ;;
    esac
  done
}

load_agent_config() {
  load_model_env
  if [ -f /etc/hmux/agent-config.sh ]; then
    . /etc/hmux/agent-config.sh
  fi
  # The machine env (\`hmux env set\`) reaches agents started through this shim
  # even when the calling shell predates the ~/.profile hook.
  if [ -f "\$HOME/.config/hmux/env" ]; then
    . "\$HOME/.config/hmux/env"
  fi
}

hmux_curl() {
  command -v curl >/dev/null 2>&1 || return 127
  if [ -f /usr/local/share/ca-certificates/freestyle-tls.crt ]; then
    curl --cacert /usr/local/share/ca-certificates/freestyle-tls.crt "\$@"
  else
    curl "\$@"
  fi
}

require_coderouter() {
  load_model_env
  hmux_coderouter_url="\${HMUX_CODEROUTER_URL:-}"
  [ -n "\$hmux_coderouter_url" ] || die_message 2 missingCodeRouter
  case "\$hmux_coderouter_url" in
    https://*) ;;
    *) die_message 2 insecureCodeRouter ;;
  esac
  case "\$hmux_coderouter_url" in
    *[!A-Za-z0-9:/._-]*)
      die_message 2 invalidCodeRouter ;;
  esac
  hmux_coderouter_key="\${OPENAI_API_KEY:-hmux-vm-edge-placeholder}"
}

# ---------------------------------------------------------------------------
# Reflection: what this machine is and what it can reach, answered by the
# control plane over the model-plane alias. The edge injects the machine's
# VM-bound route token on the way (the guest never holds it), so every answer
# is about THIS machine and nothing else. exe.dev's Reflection integration is
# the model: \`hmux whoami\`, \`hmux reflect [path]\`, and peer discovery for
# \`hmux vm …\` all read it.
# ---------------------------------------------------------------------------
# reflection_fetch <path> <out-file>: writes the body to <out-file>; sets
# hmux_rf_status (HTTP code, 000 = unreachable) and hmux_rf_base. Returns 0 on
# 2xx, 1 on any other answer, 2 when no model-plane alias is configured. Never
# exits: callers decide how loud to be. Runs in the caller's shell so the
# status survives (no subshell).
reflection_fetch() {
  hmux_rf_status=000
  hmux_rf_base=""
  load_model_env
  hmux_rf_url="\${HMUX_CODEROUTER_URL:-}"
  [ -n "\$hmux_rf_url" ] || return 2
  case "\$hmux_rf_url" in https://*) ;; *) return 2 ;; esac
  hmux_rf_base="\${hmux_rf_url%/}/api/vm/reflection"
  hmux_rf_path="\${1:-/}"
  case "\$hmux_rf_path" in /*) ;; *) hmux_rf_path="/\$hmux_rf_path" ;; esac
  # The canonical form carries no trailing slash (Next redirects '/x/' to '/x',
  # and a redirect is not an answer): the index is the bare base URL.
  while [ "\${hmux_rf_path%/}" != "\$hmux_rf_path" ]; do hmux_rf_path="\${hmux_rf_path%/}"; done
  reflection_fetch_url "\$hmux_rf_base\$hmux_rf_path" "\$2"
}

# reflection_fetch_url <url> <out-file>: one GET through the edge. The status
# rides stdout as the last line (curl --write-out), the way the image's
# bootstrap shim reads it, so both shims see the same edge the same way.
reflection_fetch_url() {
  hmux_rf_out="\$2"
  : > "\$hmux_rf_out"
  hmux_rf_raw="\$(hmux_curl -sSL --connect-timeout 5 --max-time 20 \\
    -H "authorization: Bearer \${OPENAI_API_KEY:-hmux-vm-edge-placeholder}" -H 'accept: application/json' \\
    --write-out '\\n%{http_code}' "\$1" 2>/dev/null)" || :
  hmux_rf_status="\$(printf '%s' "\$hmux_rf_raw" | tail -n 1)"
  case "\$hmux_rf_status" in ''|*[!0-9]*) hmux_rf_status=000; return 1 ;; esac
  printf '%s' "\$hmux_rf_raw" | sed '\$d' > "\$hmux_rf_out"
  case "\$hmux_rf_status" in 2[0-9][0-9]) return 0 ;; esac
  return 1
}

# One line saying why reflection did not answer: <base-url> <body-file>.
reflection_failure() {
  case "\$hmux_rf_status" in
    000) hmux_message reflectionUnreachable "\$1" ;;
    401|403) hmux_message reflectionNoIdentity "\$hmux_rf_status" ;;
    *) hmux_message reflectionError "\$hmux_rf_status" "\$(jq -r '.message // .error // empty' "\$2" 2>/dev/null || true)" ;;
  esac
}

# Print a JSON body followed by exactly one newline.
reflection_print() {
  cat "\$1"
  if [ -n "\$(tail -c 1 "\$1" 2>/dev/null)" ]; then printf '\\n'; fi
}

# self_fetch <out-file>: the identity index. Reflection's "/" is the whole
# picture (owner, plan, the owner's machines with routes); a control plane that
# answers 404 there still serves GET /api/vm/self (machine, team, machines), so
# \`hmux self\` and \`hmux vm ls\` read the same either way. Returns as
# reflection_fetch; hmux_sf_source is reflection or self.
self_fetch() {
  hmux_sf_source=reflection
  reflection_fetch / "\$1" && return 0
  hmux_sf_rc=\$?
  [ "\$hmux_sf_rc" -ne 2 ] || return 2
  [ "\$hmux_rf_status" = 404 ] || return 1
  hmux_sf_source=self
  hmux_rf_base="\${HMUX_CODEROUTER_URL%/}/api/vm/self"
  reflection_fetch_url "\$hmux_rf_base" "\$1"
}

# self_machines <index-file>: make sure the index carries machines[] (the
# owner's machines, this one flagged self). A reflection server from before the
# superset has none; its /peers plus the index itself give the same list.
self_machines() {
  if jq -e '(.machines | type) == "array"' "\$1" >/dev/null 2>&1; then return 0; fi
  [ "\$hmux_sf_source" = reflection ] || return 0
  hmux_sm_peers="\$(mktemp "\${TMPDIR:-/tmp}/hmux-peers.XXXXXX")"
  if reflection_fetch /peers "\$hmux_sm_peers"; then
    jq --slurpfile peers "\$hmux_sm_peers" '. + {machines: (
        [{id: (.provider_vm_id // .vm_id), vmId: .vm_id, name: (.display_name // .name), displayName: .display_name, slug: .name,
          status: .status, createdAt: .created_at, self: true, route: null, reachable: false}]
        + [(\$peers[0].peers // [])[] | {id: (.provider_vm_id // .vm_id), vmId: .vm_id, name: (.display_name // .name), displayName: .display_name,
          slug: .name, status: .status, self: false, route: .route, reachable: (.reachable // (.route != null)), network: .network}])}' \\
      "\$1" > "\$1.machines" 2>/dev/null && mv "\$1.machines" "\$1" || rm -f "\$1.machines"
  fi
  rm -f "\$hmux_sm_peers"
  return 0
}

# The human index: the lines main's \`hmux self\` prints, from either source.
self_human() {
  jq -r --arg self "\$(hmux_message thisMachine)" --arg team "\$(hmux_message labelTeam)" \\
    --arg machines "\$(hmux_message labelMachines)" --arg owner "\$(hmux_message labelOwner)" --arg plan "\$(hmux_message labelPlan)" '
    (.machine.name // .display_name // .name // "?") as \$name
    | (.machine.id // .provider_vm_id // .vm_id // "?") as \$id
    | (.machine.status // .status // "unknown") as \$status
    | (.team.id // .team_id // null) as \$team_id
    | (if (.machines | type) == "array" then "\\t\\(.machines | length) \\(\$machines)" else "" end) as \$count
    | (.owner.email // .owner.user_id // null) as \$owner_id
    | (.plan_id // null) as \$plan_id
    | ["\\(\$name)\\t\\(\$id)\\t\\(\$status)\\t\\(\$self)"]
      + (if \$team_id != null then ["\\(\$team)\\t\\(\$team_id)\\(\$count)"] else [] end)
      + (if \$owner_id != null then ["\\(\$owner)\\t\\(\$owner_id)"] else [] end)
      + (if \$plan_id != null then ["\\(\$plan)\\t\\(\$plan_id)"] else [] end)
    | .[]' "\$1"
}

# hmux self [<path>] [--json]: who am I, as the control plane knows it (the
# edge asserts the identity; nothing here is a credential). <path> is any
# reflection path: peers, integrations, owner, machine. whoami and reflect are
# aliases of this verb.
guest_self() {
  hmux_self_json=0
  hmux_self_path=""
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in
      --json) hmux_self_json=1 ;;
      --help|-h) hmux_message selfHelp; return 0 ;;
      -*) die "self: unknown option \$hmux_arg" 2 ;;
      *) [ -z "\$hmux_self_path" ] || die "self: one path at most (hmux self peers)" 2; hmux_self_path="\$hmux_arg" ;;
    esac
  done
  case "\$hmux_self_path" in *[!A-Za-z0-9/_.-]*) die "self: path must look like peers or /peers" 2 ;; esac
  while [ "\${hmux_self_path%/}" != "\$hmux_self_path" ]; do hmux_self_path="\${hmux_self_path%/}"; done
  hmux_self_path="\${hmux_self_path#/}"
  hmux_self_out="\$(mktemp "\${TMPDIR:-/tmp}/hmux-self.XXXXXX")"
  if [ -z "\$hmux_self_path" ]; then
    self_fetch "\$hmux_self_out" && hmux_self_rc=0 || hmux_self_rc=\$?
  else
    reflection_fetch "\$hmux_self_path" "\$hmux_self_out" && hmux_self_rc=0 || hmux_self_rc=\$?
  fi
  if [ "\$hmux_self_rc" -eq 2 ]; then rm -f "\$hmux_self_out"; die_message 2 missingCodeRouter; fi
  if [ "\$hmux_self_rc" -ne 0 ]; then
    hmux_self_why="\$(reflection_failure "\$hmux_rf_base" "\$hmux_self_out")"
    rm -f "\$hmux_self_out"
    die "\$hmux_self_why" 1
  fi
  if [ "\$hmux_self_json" -eq 1 ] || [ -n "\$hmux_self_path" ]; then
    reflection_print "\$hmux_self_out"
  elif ! self_human "\$hmux_self_out" 2>/dev/null; then
    rm -f "\$hmux_self_out"
    die_message 1 reflectionInvalid
  fi
  rm -f "\$hmux_self_out"
}

# hmux vm ls [--json]: the owner's machines from the same index, this one
# marked *. Reachability is the control plane's word (a private-network route
# exists); linked/connected is this machine's own peer-link state.
guest_vm_ls() {
  hmux_ls_json=0
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in
      --json) hmux_ls_json=1 ;;
      --help|-h) peer_usage; return 0 ;;
      *) die "usage: hmux vm ls [--json]" 2 ;;
    esac
  done
  hmux_ls_out="\$(mktemp "\${TMPDIR:-/tmp}/hmux-ls.XXXXXX")"
  self_fetch "\$hmux_ls_out" && hmux_ls_rc=0 || hmux_ls_rc=\$?
  if [ "\$hmux_ls_rc" -eq 2 ]; then rm -f "\$hmux_ls_out"; die_message 2 missingCodeRouter; fi
  if [ "\$hmux_ls_rc" -ne 0 ]; then
    hmux_ls_why="\$(reflection_failure "\$hmux_rf_base" "\$hmux_ls_out")"
    rm -f "\$hmux_ls_out"
    die "\$hmux_ls_why" 1
  fi
  self_machines "\$hmux_ls_out"
  if ! jq -e '(.machines | type) == "array"' "\$hmux_ls_out" >/dev/null 2>&1; then
    rm -f "\$hmux_ls_out"
    die_message 1 reflectionInvalid
  fi
  if [ "\$hmux_ls_json" -eq 1 ]; then
    jq -c '{machines: .machines}' "\$hmux_ls_out"
    rm -f "\$hmux_ls_out"
    return 0
  fi
  hmux_ls_tab="\$(printf '\\t')"
  # "-" stands for an empty field: a tab is IFS whitespace, so empty fields would not survive read.
  jq -r --arg self "\$(hmux_message thisMachine)" '.machines[]
    | [ (if .self then "*" else "-" end), (.name // "?"), (.id // .provider_vm_id // "?"), (.status // "unknown"),
        (if .self then \$self elif .reachable == true then "reachable" elif .reachable == false then "unreachable" else "-" end),
        (.displayName // "-"), (.slug // "-"), (.vmId // "-") ]
    | @tsv' "\$hmux_ls_out" | while IFS="\$hmux_ls_tab" read -r hmux_ls_mark hmux_ls_name hmux_ls_id hmux_ls_status hmux_ls_reach hmux_ls_display hmux_ls_slug hmux_ls_vmid; do
    hmux_ls_link=""
    if [ "\$hmux_ls_mark" != "*" ]; then
      hmux_ls_mark=" "
      for hmux_ls_key in "\$hmux_ls_name" "\$hmux_ls_display" "\$hmux_ls_slug" "\$hmux_ls_vmid" "\$hmux_ls_id"; do
        [ "\$hmux_ls_key" != "-" ] || continue
        [ -f "\$PEERS_DIR/\$hmux_ls_key.json" ] || continue
        hmux_ls_link=linked
        if [ -f "\$LINKS_DIR/\$hmux_ls_key.pid" ] && kill -0 "\$(cat "\$LINKS_DIR/\$hmux_ls_key.pid")" 2>/dev/null; then hmux_ls_link=connected; fi
        break
      done
    fi
    printf '%s %s\\t%s\\t%s' "\$hmux_ls_mark" "\$hmux_ls_name" "\$hmux_ls_id" "\$hmux_ls_status"
    [ "\$hmux_ls_reach" = "-" ] || printf '\\t%s' "\$hmux_ls_reach"
    [ -z "\$hmux_ls_link" ] || printf '\\t%s' "\$hmux_ls_link"
    printf '\\n'
  done
  rm -f "\$hmux_ls_out"
}

# When ~/.hmux/peers/<peer>.json is missing, ask reflection for the owner's
# other machines: a match on name, display name, cloud id, or provider id gives
# the private-network route, which is all the daemon's trusted-carrier listener
# needs on current images. Writes the peer file (0600) and returns 0; returns 1
# with hmux_rd_reason set otherwise (no Mac step is invented here).
reflection_discover_peer() {
  hmux_rd_peer="\$1"
  hmux_rd_reason=""
  hmux_rd_out="\$(mktemp "\${TMPDIR:-/tmp}/hmux-peers.XXXXXX")"
  if reflection_fetch /peers "\$hmux_rd_out"; then :; else
    hmux_rd_rc=\$?
    if [ "\$hmux_rd_rc" -eq 2 ]; then
      hmux_rd_reason="\$(hmux_message reflectionUnconfigured)"
    else
      hmux_rd_reason="\$(reflection_failure "\$hmux_rf_base" "\$hmux_rd_out")"
    fi
    rm -f "\$hmux_rd_out"
    return 1
  fi
  hmux_rd_match="\$(jq -c --arg p "\$hmux_rd_peer" '[.peers // [] | .[] | select(.name == \$p or .display_name == \$p or .vm_id == \$p or .provider_vm_id == \$p)] | .[0] // empty' "\$hmux_rd_out" 2>/dev/null || true)"
  if [ -z "\$hmux_rd_match" ]; then
    hmux_rd_names="\$(jq -r '[.peers // [] | .[] | .name] | join(", ")' "\$hmux_rd_out" 2>/dev/null || true)"
    [ -n "\$hmux_rd_names" ] || hmux_rd_names="\$(hmux_message noPeers)"
    hmux_rd_reason="\$(hmux_message peerUnknown "\$hmux_rd_names")"
    rm -f "\$hmux_rd_out"
    return 1
  fi
  rm -f "\$hmux_rd_out"
  hmux_rd_route="\$(printf '%s' "\$hmux_rd_match" | jq -r '.route // empty')"
  if [ -z "\$hmux_rd_route" ]; then
    hmux_rd_reason="\$(hmux_message peerUnreachable "\$hmux_rd_peer")"
    return 1
  fi
  mkdir -p "\$PEERS_DIR"
  ( umask 077; printf '%s' "\$hmux_rd_match" | jq '{route: .route, name: .name, vm_id: .vm_id, provider_vm_id: .provider_vm_id, source: "reflection"}' > "\$(peer_file "\$hmux_rd_peer")" )
  return 0
}

guest_auth_status() {
  hmux_auth_json=0
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in
      --json) hmux_auth_json=1 ;;
      --help|-h) guest_usage; return 0 ;;
      *) die_message 2 authOption "\$hmux_arg" ;;
    esac
  done
  load_model_env
  hmux_daemon_running=0
  if "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" server status >/dev/null 2>&1; then
    hmux_daemon_running=1
  fi
  hmux_model_configured=0
  hmux_tls_reachable=0
  hmux_route_auth=not_configured
  hmux_edge_status=000
  if [ -n "\${HMUX_CODEROUTER_URL:-}" ]; then
    hmux_model_configured=1
    case "\$HMUX_CODEROUTER_URL" in
      https://*)
        if hmux_edge_status="\$(hmux_curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 20 \\
          -H "authorization: Bearer \${OPENAI_API_KEY:-hmux-vm-edge-placeholder}" \\
          "\${HMUX_CODEROUTER_URL%/}/api/coderouter/vm-usage/self" 2>/dev/null)"; then :; else :; fi
        case "\$hmux_edge_status" in
          200) hmux_tls_reachable=1; hmux_route_auth=accepted ;;
          401|403) hmux_tls_reachable=1; hmux_route_auth=rejected ;;
          000|'') hmux_edge_status=000; hmux_route_auth=unreachable ;;
          *[!0-9]*) hmux_edge_status=000; hmux_route_auth=unreachable ;;
          *) hmux_tls_reachable=1; hmux_route_auth=unknown ;;
        esac
        ;;
      *) hmux_route_auth=insecure_url ;;
    esac
  fi
  hmux_authenticated=0
  hmux_daemon_authenticated=0
  if [ "\$hmux_daemon_running" -eq 1 ]; then
    hmux_daemon_authenticated=1
    [ "\$hmux_model_configured" -eq 1 ] && [ "\$hmux_route_auth" = accepted ] && hmux_authenticated=1
  fi
  hmux_daemon_bool=false
  hmux_daemon_auth_bool=false
  hmux_model_bool=false
  hmux_tls_bool=false
  # Identity: what the control plane says this machine IS (reflection). It
  # needs the same edge-injected route token the CodeRouter check needs, so a
  # missing alias or a rejected route explains an absent identity too.
  hmux_identity_json=null
  hmux_identity_line=""
  if [ "\$hmux_model_configured" -eq 1 ]; then
    hmux_id_out="\$(mktemp "\${TMPDIR:-/tmp}/hmux-identity.XXXXXX")"
    if reflection_fetch / "\$hmux_id_out"; then
      hmux_id_json="\$(jq -c '{vm_id: (.vm_id // null), name: (.name // null)} | select(.vm_id != null)' "\$hmux_id_out" 2>/dev/null || true)"
      if [ -n "\$hmux_id_json" ]; then
        hmux_identity_json="\$hmux_id_json"
        hmux_identity_line="\$(hmux_message identityLine "\$(printf '%s' "\$hmux_id_json" | jq -r '.name // "?"')" "\$(printf '%s' "\$hmux_id_json" | jq -r '.vm_id')")"
      else
        hmux_identity_line="\$(hmux_message identityUnavailable "\$(hmux_message reflectionInvalid)")"
      fi
    else
      hmux_identity_line="\$(hmux_message identityUnavailable "\$(reflection_failure "\$hmux_rf_base" "\$hmux_id_out")")"
    fi
    rm -f "\$hmux_id_out"
  else
    hmux_identity_line="\$(hmux_message identityUnavailable "\$(hmux_message reflectionUnconfigured)")"
  fi
  hmux_authenticated_bool=false
  [ "\$hmux_daemon_running" -eq 1 ] && hmux_daemon_bool=true
  [ "\$hmux_daemon_authenticated" -eq 1 ] && hmux_daemon_auth_bool=true
  [ "\$hmux_model_configured" -eq 1 ] && hmux_model_bool=true
  [ "\$hmux_tls_reachable" -eq 1 ] && hmux_tls_bool=true
  [ "\$hmux_authenticated" -eq 1 ] && hmux_authenticated_bool=true
  if [ "\$hmux_auth_json" -eq 1 ]; then
    printf '{"authenticated":%s,"daemon":{"running":%s,"authenticated":%s,"session":"%s"},"tls":{"reachable":%s},"coderouter":{"configured":%s,"route_authenticated":"%s","http_status":"%s"},"identity":%s,"control_plane":"host-only"}\\n' \\
      "\$hmux_authenticated_bool" "\$hmux_daemon_bool" "\$hmux_daemon_auth_bool" "\$LOCAL_SESSION" \\
      "\$hmux_tls_bool" "\$hmux_model_bool" "\$hmux_route_auth" "\$hmux_edge_status" "\$hmux_identity_json"
  else
    if [ "\$hmux_daemon_running" -eq 1 ]; then
      hmux_message daemonRunning "\$LOCAL_SESSION"
    else
      hmux_message daemonUnavailable "\$LOCAL_SESSION"
    fi
    if [ "\$hmux_authenticated" -eq 1 ]; then
      hmux_message authReady
    else
      hmux_message authIncomplete
    fi
    if [ "\$hmux_model_configured" -eq 0 ]; then
      hmux_message codeRouterUnconfigured
    elif [ "\$hmux_route_auth" = accepted ]; then
      hmux_message codeRouterReady "\$hmux_edge_status"
    elif [ "\$hmux_route_auth" = rejected ]; then
      hmux_message codeRouterRejected "\$hmux_edge_status"
    elif [ "\$hmux_route_auth" = insecure_url ]; then
      hmux_message codeRouterInsecure
    elif [ "\$hmux_route_auth" = unknown ]; then
      hmux_message codeRouterIndeterminate "\$hmux_edge_status"
    else
      hmux_message codeRouterUnreachable
    fi
    printf '%s\\n' "\$hmux_identity_line"
    hmux_message hostTokens
  fi
  [ "\$hmux_daemon_running" -eq 1 ] || return 1
  [ "\$hmux_authenticated" -eq 1 ] || return 1
}

# The readout of GET /api/coderouter/vm-usage/self. One text default that a
# person and an agent both read (stable \`label  value\` lines, one row per day
# with usage, a bar per row, colour only on a terminal); \`--json\` returns the
# contract unchanged (vmUsageContract.ts); \`--tsv\` is the day table alone.
# Without jq the raw body is printed, so an older image never loses it.
# Exit codes: 0 shown, 1 edge did not answer, 2 bad option, 3 ledger unavailable.

# usage_epoch <iso8601>: seconds since the epoch, GNU date first (the guest),
# BSD date second (a Mac running the tests); empty when neither parses it.
usage_epoch() {
  date -u -d "\$1" +%s 2>/dev/null && return 0
  date -u -j -f '%Y-%m-%dT%H:%M:%S' "\${1%%.*}" +%s 2>/dev/null
}

# usage_asof_text <iso8601>: "as of 2 min ago, 23:24 UTC"; only the absolute
# time when the age cannot be computed. HMUX_NOW_EPOCH pins "now" for tests.
usage_asof_text() {
  hmux_ua_abs="\$(printf '%s' "\$1" | sed -e 's/T/ /' -e 's/:[0-9][0-9]\\(\\.[0-9]*\\)\\{0,1\\}Z\$/ UTC/')"
  hmux_ua_then="\$(usage_epoch "\$1" || true)"
  hmux_ua_now="\${HMUX_NOW_EPOCH:-\$(date -u +%s)}"
  if [ -n "\$hmux_ua_then" ] && [ "\$hmux_ua_now" -ge "\$hmux_ua_then" ] 2>/dev/null; then
    hmux_ua_age=\$(( (hmux_ua_now - hmux_ua_then) / 60 ))
    if [ "\$hmux_ua_age" -lt 60 ]; then hmux_ua_rel="\$(hmux_message usageAgoMinutes "\$hmux_ua_age")"
    elif [ "\$hmux_ua_age" -lt 1440 ]; then hmux_ua_rel="\$(hmux_message usageAgoHours "\$((hmux_ua_age / 60))")"
    else hmux_ua_rel="\$(hmux_message usageAgoDays "\$((hmux_ua_age / 1440))")"; fi
    hmux_message usageAsOf "\$(hmux_message usageAgo "\$hmux_ua_rel" "\$hmux_ua_abs")"
  else
    hmux_message usageAsOf "\$hmux_ua_abs"
  fi
}

# usage_tsv <file> <days>: day, tokens, api_equivalent_usd, zeros included.
usage_tsv() {
  printf 'day\\ttokens\\tapi_equivalent_usd\\n'
  jq -r --argjson days "\$2" '(.days // []) | .[-\$days:] | .[] | [.day, (.totalTokens // 0), (.apiEquivalentUsd // 0)] | @tsv' "\$1"
}

guest_coderouter_usage_render() {
  hmux_cu_file="\$1"
  hmux_cu_days="\$2"
  if ! jq -e . "\$hmux_cu_file" >/dev/null 2>&1; then cat "\$hmux_cu_file"; return 0; fi
  if jq -e '.kind == "unavailable"' "\$hmux_cu_file" >/dev/null 2>&1; then
    hmux_message usageUnavailable
    return 3
  fi
  # Anything that is not the ready contract (an error body, a future shape,
  # a non-numeric field) is passed through untouched rather than formatted.
  if ! jq -e '.kind == "ready" and (.totals | type) == "object" and (.periodDays | type) == "number" and (.asOf | type) == "string"
      and ([.totals.inputTokens, .totals.cachedInputTokens, .totals.outputTokens, .totals.totalTokens, .totals.apiEquivalentUsd] | all(type == "number"))
      and ((.days // []) | type) == "array"
      and ((.days // []) | all((.day | type) == "string" and (.totalTokens | type) == "number" and (.apiEquivalentUsd | type) == "number"))' \\
      "\$hmux_cu_file" >/dev/null 2>&1; then
    cat "\$hmux_cu_file"
    return 0
  fi
  if [ "\$hmux_cu_format" = tsv ]; then usage_tsv "\$hmux_cu_file" "\$hmux_cu_days"; return 0; fi
  eval "\$(jq -r '@sh "hmux_cu_period=\\(.periodDays // 30) hmux_cu_asof=\\(.asOf // "?") hmux_cu_name=\\(.displayName // .vmId // "?") hmux_cu_total=\\(.totals.totalTokens // 0)"' "\$hmux_cu_file")"
  # Workspace ids come from the ledger; their names live in this machine's
  # hmux-tui. Best effort: no daemon, or an old one, leaves the ids visible.
  # Ids are never shown: named (live) workspaces print by name, the rest fold
  # into one "closed workspaces" entry, and when the lookup itself fails the
  # workspace line is dropped rather than printed as ids.
  hmux_cu_names='{}'
  hmux_cu_names_ok=false
  if [ -x "\$HMUX_TUI_BIN" ]; then
    hmux_cu_names="\$("\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" workspace list --json 2>/dev/null \\
      | jq -c '[.workspaces[]? | select(.id != null and .name != null) | {key: .id, value: .name}] | from_entries' 2>/dev/null || true)"
    case "\$hmux_cu_names" in '{'*) hmux_cu_names_ok=true ;; *) hmux_cu_names='{}' ;; esac
  fi
  hmux_cu_bold=""; hmux_cu_dim=""; hmux_cu_reset=""
  if [ -t 1 ] && [ -z "\${NO_COLOR:-}" ]; then
    hmux_cu_bold="\$(printf '\\033[1m')"; hmux_cu_dim="\$(printf '\\033[2m')"; hmux_cu_reset="\$(printf '\\033[0m')"
  fi
  printf '%s%s%s\\n' "\$hmux_cu_bold" "\$(hmux_message usageTitle "\$hmux_cu_name" "\$hmux_cu_period" "\$(usage_asof_text "\$hmux_cu_asof")")" "\$hmux_cu_reset"
  jq -r --argjson days "\$hmux_cu_days" \\
    --arg bold "\$hmux_cu_bold" --arg dim "\$hmux_cu_dim" --arg reset "\$hmux_cu_reset" \\
    --arg machine "\$(hmux_message labelMachine)" --arg tokens "\$(hmux_message labelTokens)" \\
    --arg cost "\$(hmux_message labelCost)" --arg trend "\$(hmux_message labelTrend)" --arg day "\$(hmux_message labelDay)" \\
    --arg total "\$(hmux_message labelTotal)" --arg input "\$(hmux_message labelInput)" --arg cached "\$(hmux_message labelCached)" \\
    --arg output "\$(hmux_message labelOutput)" --arg api "\$(hmux_message labelApiEquivalent)" \\
    --arg costNote "\$(hmux_message usageCostNote)" --arg costUnpriced "\$(hmux_message usageCostUnpriced)" \\
    --arg trendTpl "\$(hmux_message usageTrend "%1" "%2")" --argjson names "\$hmux_cu_names" \\
    --arg workspace "\$(hmux_message labelWorkspace)" --arg agentLabel "\$(hmux_message labelAgent)" --arg model "\$(hmux_message labelModel)" \\
    --arg noWorkspace "\$(hmux_message usageNoWorkspace)" --arg closedWorkspaces "\$(hmux_message usageClosedWorkspaces)" \\
    --argjson namesOk "\$hmux_cu_names_ok" --arg moreTpl "\$(hmux_message usageMore "%1")" '
    def commas: tostring | (length - 1) as \$n
      | [range(0; length) as \$i | .[\$i:\$i+1] + (if (\$n - \$i) > 0 and ((\$n - \$i) % 3 == 0) then "," else "" end)] | join("");
    def whole: (. // 0) | floor | commas;
    def usd: (. // 0) as \$v | ((\$v * 100) | round) as \$c
      | if \$v > 0 and \$c == 0 then "<\$0.01"
        else "\$" + ((\$c / 100 | floor) | commas) + "." + ((\$c % 100) | tostring | if length < 2 then "0" + . else . end) end;
    def lpad(\$w): tostring | if length >= \$w then . else (" " * (\$w - length)) + . end;
    def rpad(\$w): tostring | if length >= \$w then . else . + (" " * (\$w - length)) end;
    def bar(\$max): if . <= 0 or \$max <= 0 then "" else ((. * 12 / \$max) | ceil | if . < 1 then 1 else . end) as \$n | ("█" * \$n) end;
    def share(\$all): if \$all > 0 then " (\\((. * 100 / \$all) | round)%)" else "" end;
    def section(\$label; \$items; \$lw; \$total): if (\$items | length) == 0 then empty else
        "\\(\$label | rpad(\$lw))  " + ([\$items[:5][] | "\\(.name) \\(.totals.totalTokens | whole)\\(.totals.totalTokens | share(\$total))"] | join("   "))
        + (if (\$items | length) > 5 then "   \\(\$dim)\\(\$moreTpl | sub("%1"; ((\$items | length) - 5 | tostring)))\\(\$reset)" else "" end) end;
    .totals as \$t
    | (.workspaces // []) as \$rawWs
    | (\$rawWs | map(select(.workspaceId != null and \$names[.workspaceId] != null) | {name: \$names[.workspaceId], totals})) as \$namedWs
    | (\$rawWs | map(select(.workspaceId != null and \$names[.workspaceId] == null))) as \$unnamedWs
    | (\$rawWs | map(select(.workspaceId == null) | {name: \$noWorkspace, totals})) as \$outsideWs
    | (if (\$unnamedWs | length) > 0 and (\$namesOk | not) then []
       else (\$namedWs + \$outsideWs
             + (if (\$unnamedWs | length) > 0 then [{name: \$closedWorkspaces, totals: {totalTokens: (\$unnamedWs | map(.totals.totalTokens) | add)}}] else [] end))
            | sort_by(-.totals.totalTokens) end) as \$ws
    | ((.agents // []) | map({name: .agent, totals})) as \$ag
    | ((.models // []) | map({name: .model, totals})) as \$md
    | (.days // []) as \$all
    | ([\$machine, \$tokens, \$cost] + (if (\$all | length) >= 8 then [\$trend] else [] end)
        + (if (\$ws | length) > 0 then [\$workspace] else [] end) + (if (\$ag | length) > 0 then [\$agentLabel] else [] end)
        + (if (\$md | length) > 0 then [\$model] else [] end) | map(length) | max) as \$lw
    | (\$all | .[-\$days:]) as \$window
    | (\$window | map(select((.totalTokens // 0) > 0))) as \$rows
    | (\$all | .[-7:] | map(.totalTokens // 0) | add // 0) as \$last7
    | (\$all | .[-14:-7] | map(.totalTokens // 0) | add // 0) as \$prior7
    | (\$rows | map(.totalTokens) | max // 0) as \$max
    | "\\(\$machine | rpad(\$lw))  \\(.displayName // .vmId // "?")\\(if .displayName != null then "  \\(\$dim)\\(.vmId)\\(\$reset)" else "" end)",
      "\\(\$tokens | rpad(\$lw))  \\(\$bold)\\(\$t.totalTokens | whole)\\(\$reset) \\(\$total) = \\(\$t.inputTokens | whole) \\(\$input) (\\(\$t.cachedInputTokens | whole) \\(\$cached)) + \\(\$t.outputTokens | whole) \\(\$output)",
      "\\(\$cost | rpad(\$lw))  \\(\$t.apiEquivalentUsd | usd) \\(\$api)  \\(\$dim)(\\(if \$t.totalTokens > 0 and \$t.apiEquivalentUsd == 0 then \$costUnpriced else \$costNote end))\\(\$reset)",
      (if (\$all | length) >= 8 then "\\(\$trend | rpad(\$lw))  \\(\$trendTpl | sub("%1"; (\$last7 | commas)) | sub("%2"; (\$prior7 | commas)))" else empty end),
      section(\$workspace; \$ws; \$lw; \$t.totalTokens), section(\$agentLabel; \$ag; \$lw; \$t.totalTokens), section(\$model; \$md; \$lw; \$t.totalTokens),
      (if (\$rows | length) > 0 then
        ([\$rows[].totalTokens | whole | length] + [(\$tokens | length)] | max) as \$tw
        | ([\$rows[].apiEquivalentUsd | usd | length] + [(\$cost | length)] | max) as \$cw
        | "",
          "\\(\$dim)\\(\$day | rpad(10))  \\(\$tokens | lpad(\$tw))  \\(\$cost | lpad(\$cw))\\(\$reset)",
          (\$rows[] | "\\(.day | rpad(10))  \\(.totalTokens | whole | lpad(\$tw))  \\(.apiEquivalentUsd | usd | lpad(\$cw))  \\(.totalTokens | bar(\$max))")
      else empty end),
      "@omitted \\((\$window | length) - (\$rows | length)) \\(\$window | length)"
  ' "\$hmux_cu_file" | while IFS= read -r hmux_cu_line; do
    case "\$hmux_cu_line" in
      "@omitted "*)
        set -- \$hmux_cu_line
        if [ "\$hmux_cu_total" -eq 0 ] 2>/dev/null; then
          printf '\\n'; hmux_message usageNone "\$hmux_cu_period"
        elif [ "\$2" -gt 0 ] 2>/dev/null; then
          printf '%s' "\$hmux_cu_dim"; hmux_message usageOmitted "\$2" "\$3"; printf '%s' "\$hmux_cu_reset"
        fi
        ;;
      *) printf '%s\\n' "\$hmux_cu_line" ;;
    esac
  done
  printf '\\n%s' "\$hmux_cu_dim"
  hmux_message usageJsonHint
  hmux_message usageTeamHint "https://cmux.com/dashboard/coderouter"
  printf '%s' "\$hmux_cu_reset"
}

guest_coderouter_usage() {
  hmux_cu_format=text
  hmux_cu_days=30
  [ "\${HMUX_OUTPUT:-}" != json ] || hmux_cu_format=json
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --json) hmux_cu_format=json ;;
      --tsv) hmux_cu_format=tsv ;;
      --days)
        shift
        case "\${1:-}" in
          ''|*[!0-9]*) die_message 2 usageDays "\${1:-}" ;;
        esac
        [ "\$1" -ge 1 ] && [ "\$1" -le 30 ] || die_message 2 usageDays "\$1"
        hmux_cu_days="\$1"
        ;;
      --days=*)
        hmux_cu_days="\${1#--days=}"
        case "\$hmux_cu_days" in ''|*[!0-9]*) die_message 2 usageDays "\$hmux_cu_days" ;; esac
        [ "\$hmux_cu_days" -ge 1 ] && [ "\$hmux_cu_days" -le 30 ] || die_message 2 usageDays "\$hmux_cu_days"
        ;;
      --help|-h) hmux_message usageHelp; return 0 ;;
      *) die_message 2 usageOption "\$1" ;;
    esac
    shift
  done
  require_coderouter
  hmux_response="\$(hmux_curl -fsS --connect-timeout 5 --max-time 20 \\
    -H "authorization: Bearer \$hmux_coderouter_key" \\
    "\${hmux_coderouter_url%/}/api/coderouter/vm-usage/self" 2>&1)" || {
    printf '%s\\n' "\$hmux_response" >&2
    return 1
  }
  if [ "\$hmux_cu_format" = json ] || ! command -v jq >/dev/null 2>&1; then
    printf '%s\\n' "\$hmux_response"
    if [ "\$hmux_cu_format" = json ] && command -v jq >/dev/null 2>&1 \\
      && printf '%s' "\$hmux_response" | jq -e '.kind == "unavailable"' >/dev/null 2>&1; then return 3; fi
    return 0
  fi
  hmux_cu_out="\$(mktemp "\${TMPDIR:-/tmp}/hmux-usage.XXXXXX")"
  printf '%s\\n' "\$hmux_response" > "\$hmux_cu_out"
  hmux_cu_rc=0
  guest_coderouter_usage_render "\$hmux_cu_out" "\$hmux_cu_days" || hmux_cu_rc=\$?
  rm -f "\$hmux_cu_out"
  return "\$hmux_cu_rc"
}

guest_coderouter_models() {
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in
      --json) ;;
      --help|-h) guest_usage; return 0 ;;
      *) die_message 2 modelsOption "\$hmux_arg" ;;
    esac
  done
  require_coderouter
  hmux_response="\$(hmux_curl -fsS --connect-timeout 5 --max-time 20 \\
    -H "authorization: Bearer \$hmux_coderouter_key" -H "accept: application/json" \\
    "\${hmux_coderouter_url%/}/v1/models" 2>&1)" || {
    printf '%s\\n' "\$hmux_response" >&2
    return 1
  }
  printf '%s\\n' "\$hmux_response"
}

# Run the agent in this terminal; with --timeout, under timeout(1) (exit 1 and
# a message when the cap is hit, the agent's own code otherwise).
agent_exec() {
  if [ -n "\${hmux_ag_timeout:-}" ]; then
    hmux_ag_bin="\$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)"
    if [ -n "\$hmux_ag_bin" ]; then
      "\$hmux_ag_bin" -k 5 "\$hmux_ag_timeout" "\$@" && return 0
      hmux_ag_rc=\$?
      [ "\$hmux_ag_rc" -ne 124 ] || die "agent \$hmux_agent timed out after \${hmux_ag_timeout}s" 1
      exit "\$hmux_ag_rc"
    fi
    warn "no timeout(1) on this machine; running \$hmux_agent without a cap"
  fi
  exec "\$@"
}

guest_coderouter_agent() {
  hmux_agent="\${1:-}"
  [ -n "\$hmux_agent" ] || die_message 2 agentUsage
  if [ "\$hmux_agent" = "--agent" ]; then
    shift
    hmux_agent="\${1:-}"
    [ -n "\$hmux_agent" ] || die_message 2 agentUsage
  fi
  shift
  case "\$hmux_agent" in
    claude|codex|opencode|pi) ;;
    *) die_message 2 unsupportedAgent "\$hmux_agent" ;;
  esac
  # This form runs the agent right here, in the caller's terminal, so it is
  # already the wait and its output is already the output: --wait and --output
  # are accepted for parity with \`hmux vm agent <machine> …\`; --timeout caps it.
  hmux_ag_timeout=""
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --wait|--output) shift ;;
      --timeout) [ "\$#" -ge 2 ] || die "agent: --timeout needs seconds" 2; hmux_ag_timeout="\$2"; shift 2 ;;
      --timeout=*) hmux_ag_timeout="\${1#--timeout=}"; shift ;;
      *) break ;;
    esac
  done
  [ -z "\$hmux_ag_timeout" ] || timeout_ms "\$hmux_ag_timeout" "agent" >/dev/null
  load_agent_config
  # Match the host vm-agent contract: a bare sentence becomes the provider's
  # one-shot form, while flags/subcommands are passed through byte-for-byte.
  if [ "\$#" -eq 0 ]; then
    agent_exec "\$hmux_agent"
  fi
  if [ "\$1" = "--" ]; then
    shift
    [ "\$#" -gt 0 ] || die_message 2 agentUsage
    hmux_prompt="\$*"
    case "\$hmux_agent" in
      claude) set -- claude -p "\$hmux_prompt" ;;
      codex) set -- codex exec "\$hmux_prompt" ;;
      opencode) set -- opencode run "\$hmux_prompt" ;;
      pi) set -- pi -p "\$hmux_prompt" ;;
    esac
    agent_exec "\$@"
  fi
  hmux_first="\$1"
  case "\$hmux_first" in
    -*|mcp|config|doctor|update|install|auth|setup-token|plugin|agents|exec|e|login|logout|apply|resume|completion|debug|sandbox|cloud|app-server|features|run|serve|web|models|upgrade|agent|session|export|import|github|acp|list)
      agent_exec "\$hmux_agent" "\$@"
      ;;
    *)
      hmux_prompt="\$*"
      case "\$hmux_agent" in
        claude) set -- claude -p "\$hmux_prompt" ;;
        codex) set -- codex exec "\$hmux_prompt" ;;
        opencode) set -- opencode run "\$hmux_prompt" ;;
        pi) set -- pi -p "\$hmux_prompt" ;;
      esac
      agent_exec "\$@"
      ;;
  esac
}

guest_agent_command() {
  case "\${1:-}" in
    claude|codex|opencode|pi|--agent)
      guest_coderouter_agent "\$@"
      ;;
    list|report|hook)
      exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" agent "\$@"
      ;;
    help|--help|-h|"")
      guest_usage
      ;;
    *)
      die_message 2 agentCommand "\$1"
      ;;
  esac
}

${GUEST_CODEROUTER_SHELL}
${GUEST_CODEROUTER_USE_SHELL}
guest_coderouter_command() {
  hmux_coderouter_sub="\${1:-help}"
  [ "\$#" -gt 0 ] && shift
  case "\$hmux_coderouter_sub" in
    accounts|list|ls) guest_coderouter_accounts "\$@" ;;
    org|organization|team) guest_coderouter_org "\$@" ;;
    status|auth) guest_auth_status "\$@" ;;
    usage|machines) guest_coderouter_usage "\$@" ;;
    models) guest_coderouter_models "\$@" ;;
    agent|run) guest_coderouter_agent "\$@" ;;
    use) guest_coderouter_use "\$@" ;;
    help|--help|-h) guest_usage ;;
    claude|login|logout)
      die_message 2 accountHostOnly "\$hmux_coderouter_sub"
      ;;
    *) die_message 2 unknownCodeRouter "\$hmux_coderouter_sub" ;;
  esac
}

host_only_command() {
  die_message 2 hostOwned "\$1"
}

local_alias() {
  case "\$1" in
    list-workspaces)
      shift
      exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" workspace list "\$@"
      ;;
    current-workspace)
      shift
      exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" workspace current show "\$@"
      ;;
    list-panes)
      shift
      exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" pane list "\$@"
      ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Machine env: ~/.config/hmux/env, sourced by every login/interactive shell on
# this machine (hook lines in ~/.profile and ~/.bashrc, installed here) and by
# agents started through this shim. \`hmux vm env …\` on the Mac drives these
# same verbs, so the Mac and the machine cannot disagree about the file.
# ---------------------------------------------------------------------------
env_file() { printf '%s/.config/hmux/env' "\${HOME:-/root}"; }
ENV_HOOK_LINE='[ -f "\$HOME/.config/hmux/env" ] && . "\$HOME/.config/hmux/env" # hmux-env-hook'

env_usage() {
  hmux_message envHelp
}

env_key_ok() {
  case "\$1" in
    ''|[0-9]*|*[!A-Za-z0-9_]*) return 1 ;;
  esac
  return 0
}

# Single-quote a value for an \`export KEY='…'\` line (' becomes '\\'').
env_quote() { printf '%s\\n' "\$1" | sed "s/'/'\\\\\\\\''/g"; }

env_parse_dotenv_value() {
  awk '
    {
      value = $0
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      quote = substr(value, 1, 1)
      if (quote == sprintf("%c", 34) || quote == sprintf("%c", 39)) {
        escaped = 0
        for (offset = 2; offset <= length(value); offset++) {
          character = substr(value, offset, 1)
          if (character == quote && !escaped) {
            suffix = substr(value, offset + 1)
            sub(/^[[:space:]]+/, "", suffix)
            if (suffix == "" || substr(suffix, 1, 1) == "#") {
              print substr(value, 2, offset - 2)
              next
            }
          }
          escaped = character == sprintf("%c", 92) && !escaped
        }
      }
      sub(/[[:space:]]+#.*$/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
    }'
}

# stdin: dotenv text → stdout: KEY=VALUE lines (comments/blank lines dropped,
# a leading \`export \` removed, one pair of matching quotes stripped).
env_parse_dotenv() {
  hmux_cr="\$(printf '\\r')"
  while IFS= read -r hmux_line || [ -n "\$hmux_line" ]; do
    hmux_line="\${hmux_line%"\$hmux_cr"}"
    hmux_line="\$(printf '%s\\n' "\$hmux_line" | sed 's/^[[:space:]]*//')"
    case "\$hmux_line" in ''|'#'*) continue ;; esac
    case "\$hmux_line" in
      'export '*|'export	'*)
        hmux_line="\${hmux_line#export}"
        hmux_line="\$(printf '%s\\n' "\$hmux_line" | sed 's/^[[:space:]]*//')"
        ;;
    esac
    case "\$hmux_line" in *=*) ;; *) die "env: malformed line (expected KEY=VALUE): \$hmux_line" 2 ;; esac
    hmux_key="\${hmux_line%%=*}"
    hmux_key="\$(printf '%s\\n' "\$hmux_key" | sed 's/[[:space:]]*\$//')"
    hmux_val="\$(printf '%s\\n' "\${hmux_line#*=}" | env_parse_dotenv_value)"
    printf '%s=%s\\n' "\$hmux_key" "\$hmux_val"
  done
  return 0
}

# stdout: KEY=VALUE lines decoded from the managed file (nothing when absent).
env_decoded_lines() {
  [ -f "\$1" ] || return 0
  grep '^export [A-Za-z_][A-Za-z0-9_]*=' "\$1" 2>/dev/null | while IFS= read -r hmux_line; do
    hmux_rest="\${hmux_line#export }"
    hmux_key="\${hmux_rest%%=*}"
    hmux_q="\${hmux_rest#*=}"
    hmux_q="\${hmux_q#\\'}"
    hmux_q="\${hmux_q%\\'}"
    hmux_val="\$(printf '%s\\n' "\$hmux_q" | sed "s/'\\\\\\\\''/'/g")"
    printf '%s=%s\\n' "\$hmux_key" "\$hmux_val"
  done
  return 0
}

# stdin: the complete new file body → written atomically with mode 0600.
env_write() {
  hmux_env_path="\$(env_file)"
  mkdir -p "\${hmux_env_path%/*}"
  (
    umask 077
    cat > "\$hmux_env_path.tmp"
  )
  chmod 600 "\$hmux_env_path.tmp"
  mv -f "\$hmux_env_path.tmp" "\$hmux_env_path"
}

env_hook_into() {
  if [ -f "\$1" ] && grep -q 'hmux-env-hook' "\$1" 2>/dev/null; then return 0; fi
  printf '\\n%s\\n' "\$ENV_HOOK_LINE" >> "\$1"
  return 0
}

# ~/.profile (login shells, incl. \`bash -l\` from the Mac and dash -l) and
# ~/.bashrc (interactive shells). ~/.bash_profile shadows ~/.profile for bash
# login shells, so it gets the line too — but only when it already exists.
env_install_hook() {
  env_hook_into "\${HOME:-/root}/.profile"
  env_hook_into "\${HOME:-/root}/.bashrc"
  if [ -f "\${HOME:-/root}/.bash_profile" ]; then env_hook_into "\${HOME:-/root}/.bash_profile"; fi
  return 0
}

# Rewrite the managed file from KEY=VALUE lines on stdin (replacing those keys,
# keeping every other key), sorted by key.
env_merge_and_write() {
  hmux_env_path="\$(env_file)"
  hmux_env_tmp="\$(mktemp "\${TMPDIR:-/tmp}/hmux-env.XXXXXX")"
  hmux_env_new="\$(mktemp "\${TMPDIR:-/tmp}/hmux-env.XXXXXX")"
  cat > "\$hmux_env_new"
  : > "\$hmux_env_tmp"
  while IFS= read -r hmux_pair || [ -n "\$hmux_pair" ]; do
    [ -n "\$hmux_pair" ] || continue
    hmux_key="\${hmux_pair%%=*}"
    hmux_val="\${hmux_pair#*=}"
    env_key_ok "\$hmux_key" || { rm -f "\$hmux_env_tmp" "\$hmux_env_new"; die "env: invalid key '\$hmux_key' (letters, digits and _ only, not starting with a digit)" 2; }
    # Later assignments of the same key win.
    grep -v "^export \$hmux_key=" "\$hmux_env_tmp" > "\$hmux_env_tmp.next" || true
    mv -f "\$hmux_env_tmp.next" "\$hmux_env_tmp"
    printf "export %s='%s'\\n" "\$hmux_key" "\$(env_quote "\$hmux_val")" >> "\$hmux_env_tmp"
  done < "\$hmux_env_new"
  if [ -f "\$hmux_env_path" ]; then
    grep '^export [A-Za-z_][A-Za-z0-9_]*=' "\$hmux_env_path" 2>/dev/null | while IFS= read -r hmux_line; do
      hmux_key="\${hmux_line#export }"
      hmux_key="\${hmux_key%%=*}"
      grep -q "^export \$hmux_key=" "\$hmux_env_tmp" || printf '%s\\n' "\$hmux_line" >> "\$hmux_env_tmp"
    done
  fi
  {
    printf '%s\\n' "# managed by hmux env; KEY='value' lines; edit with hmux env set/rm"
    LC_ALL=C sort -t = -k 1,1 "\$hmux_env_tmp"
  } | env_write
  rm -f "\$hmux_env_tmp" "\$hmux_env_new"
  env_install_hook
}

# Collect literal KEY=VALUE lines into file \$1 from the remaining arguments:
# KEY=VALUE words, --from-file <.env> (dotenv), or \`-\` (dotenv on stdin).
env_collect_input() {
  hmux_ec_file="\$1"
  shift
  : > "\$hmux_ec_file"
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --from-file)
        [ "\$#" -ge 2 ] || die "env set: --from-file needs a path" 2
        [ -f "\$2" ] || die "env set: no such file \$2" 2
        env_parse_dotenv < "\$2" >> "\$hmux_ec_file"
        shift 2
        ;;
      --from-file=*)
        [ -f "\${1#--from-file=}" ] || die "env set: no such file \${1#--from-file=}" 2
        env_parse_dotenv < "\${1#--from-file=}" >> "\$hmux_ec_file"
        shift
        ;;
      -)
        env_parse_dotenv >> "\$hmux_ec_file"
        shift
        ;;
      --json) shift ;;
      -*) die "env set: unknown option \$1" 2 ;;
      *)
        case "\$1" in
          *=*)
            [ "\$(printf '%s' "\$1" | tr -d '\\r\\n')" = "\$1" ] || die_message 2 envSingleLineValue
            printf '%s\\n' "\$1" >> "\$hmux_ec_file"
            ;;
          *) die "env set: expected KEY=VALUE, got '\$1'" 2 ;;
        esac
        shift
        ;;
    esac
  done
  [ -s "\$hmux_ec_file" ] || die "env set: nothing to set (pass KEY=VALUE, --from-file <path>, or - for stdin)" 2
  # Keys are checked here, before anything is written, so a bad line never half-applies.
  while IFS= read -r hmux_ec_pair || [ -n "\$hmux_ec_pair" ]; do
    [ -n "\$hmux_ec_pair" ] || continue
    env_key_ok "\${hmux_ec_pair%%=*}" || die "env: invalid key '\${hmux_ec_pair%%=*}' (letters, digits and _ only, not starting with a digit)" 2
  done < "\$hmux_ec_file"
}

guest_env_set() {
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in --help|-h) env_usage; return 0 ;; esac
  done
  hmux_env_input="\$(mktemp "\${TMPDIR:-/tmp}/hmux-env.XXXXXX")"
  env_collect_input "\$hmux_env_input" "\$@"
  env_merge_and_write < "\$hmux_env_input"
  hmux_env_count="\$(grep -c . "\$hmux_env_input" || true)"
  rm -f "\$hmux_env_input"
  printf 'OK set %s variable%s in %s (new hmux shells and agents see them)\\n' "\$hmux_env_count" "\$([ "\$hmux_env_count" = 1 ] || printf s)" "\$(env_file)"
}

# The receiving end of \`hmux vm env set\` (Mac → machine, or peer → peer):
# values never ride the provider exec API or any argv. The sender starts
# \`hmux env receive\` in a terminal over the Noise-encrypted hmux-tui link,
# waits for HMUX-ENV-READY (echo is off by then, so nothing lands on the
# screen), types base64 lines and a HMUX-ENV-END line, and reads back one
# HMUX-ENV-OK keys=<n> path=<file> or HMUX-ENV-ERR <reason> line.
env_receive_cleanup() {
  if [ -n "\${hmux_er_dir:-}" ]; then rm -rf "\$hmux_er_dir"; fi
  if [ -n "\${hmux_er_dog:-}" ]; then kill "\$hmux_er_dog" 2>/dev/null || true; fi
  if [ "\${hmux_er_tty:-0}" -eq 1 ]; then stty echo 2>/dev/null || true; fi
  return 0
}

guest_env_receive() {
  hmux_er_stdin=0
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in
      --stdin) hmux_er_stdin=1 ;;
      --help|-h) env_usage; return 0 ;;
      *) die "env receive: unknown option \$hmux_arg" 2 ;;
    esac
  done
  umask 077
  hmux_er_tty=0
  if [ "\$hmux_er_stdin" -eq 0 ] && [ -t 0 ]; then
    if stty -echo 2>/dev/null; then hmux_er_tty=1; fi
  fi
  hmux_er_dir="\$(mktemp -d "\${TMPDIR:-/tmp}/hmux-env-recv.XXXXXX")"
  # Watchdog: a sender that never finishes must not leave a receiver holding
  # the terminal forever.
  # (\$\$ inside the subshell is still the receiver's pid. It polls once a second
  # and stops by itself once the scratch dir is gone, so nothing lingers.)
  ( hmux_er_i=0; while [ -d "\$hmux_er_dir" ] && [ "\$hmux_er_i" -lt 120 ]; do sleep 1; hmux_er_i=\$((hmux_er_i + 1)); done; if [ -d "\$hmux_er_dir" ]; then kill -TERM \$\$ 2>/dev/null; fi ) </dev/null >/dev/null 2>&1 &
  hmux_er_dog=\$!
  trap 'env_receive_cleanup' EXIT
  trap 'printf "HMUX-ENV-ERR timeout\\n"; exit 1' TERM
  trap 'printf "HMUX-ENV-ERR interrupted\\n"; exit 1' INT HUP
  printf 'HMUX-ENV-READY\\n'
  hmux_er_bytes=0
  hmux_er_end=0
  hmux_er_cr="\$(printf '\\r')"
  while IFS= read -r hmux_er_line; do
    hmux_er_line="\${hmux_er_line%"\$hmux_er_cr"}"
    if [ "\$hmux_er_line" = HMUX-ENV-END ]; then hmux_er_end=1; break; fi
    [ -n "\$hmux_er_line" ] || continue
    hmux_er_bytes=\$((hmux_er_bytes + \${#hmux_er_line}))
    if [ "\$hmux_er_bytes" -gt 524288 ]; then printf 'HMUX-ENV-ERR too-large\\n'; exit 1; fi
    printf '%s\\n' "\$hmux_er_line" >> "\$hmux_er_dir/b64"
  done
  if [ "\$hmux_er_end" -ne 1 ]; then printf 'HMUX-ENV-ERR eof\\n'; exit 1; fi
  if [ ! -s "\$hmux_er_dir/b64" ]; then printf 'HMUX-ENV-ERR empty\\n'; exit 1; fi
  if ! base64 -d < "\$hmux_er_dir/b64" > "\$hmux_er_dir/payload" 2>/dev/null; then printf 'HMUX-ENV-ERR bad-base64\\n'; exit 1; fi
  # The payload is literal KEY=VALUE lines (the sender already parsed dotenv):
  # no trimming, no quote stripping. Validate every key before writing anything.
  hmux_er_n=0
  while IFS= read -r hmux_er_pair || [ -n "\$hmux_er_pair" ]; do
    [ -n "\$hmux_er_pair" ] || continue
    case "\$hmux_er_pair" in
      *=*) ;;
      *) printf 'HMUX-ENV-ERR invalid-key %s\\n' "\$hmux_er_pair"; exit 1 ;;
    esac
    if ! env_key_ok "\${hmux_er_pair%%=*}"; then printf 'HMUX-ENV-ERR invalid-key %s\\n' "\${hmux_er_pair%%=*}"; exit 1; fi
    hmux_er_n=\$((hmux_er_n + 1))
  done < "\$hmux_er_dir/payload"
  if [ "\$hmux_er_n" -eq 0 ]; then printf 'HMUX-ENV-ERR empty\\n'; exit 1; fi
  if ! env_merge_and_write < "\$hmux_er_dir/payload"; then printf 'HMUX-ENV-ERR write-failed\\n'; exit 1; fi
  printf 'HMUX-ENV-OK keys=%s path=%s\\n' "\$hmux_er_n" "\$(env_file)"
}

guest_env_ls() {
  hmux_env_show=0
  hmux_env_json=0
  for hmux_arg in "\$@"; do
    case "\$hmux_arg" in
      --show|--values) hmux_env_show=1 ;;
      --json) hmux_env_json=1 ;;
      --help|-h) env_usage; return 0 ;;
      *) die "env ls: unknown option \$hmux_arg" 2 ;;
    esac
  done
  hmux_env_path="\$(env_file)"
  if [ "\$hmux_env_json" -eq 1 ]; then
    env_decoded_lines "\$hmux_env_path" | jq -Rn --arg path "\$hmux_env_path" --argjson show "\$hmux_env_show" '
      [inputs | capture("^(?<k>[A-Za-z_][A-Za-z0-9_]*)=(?<v>.*)\$")] as \$pairs
      | {path: \$path, keys: (\$pairs | map(.k))}
        + (if \$show == 1 then {values: ((\$pairs | map({(.k): .v}) | add) // {})} else {} end)'
    return 0
  fi
  if [ ! -f "\$hmux_env_path" ]; then
    printf 'no machine env yet (set one with: hmux env set KEY=VALUE)\\n'
    return 0
  fi
  if [ "\$hmux_env_show" -eq 1 ]; then
    env_decoded_lines "\$hmux_env_path"
  else
    env_decoded_lines "\$hmux_env_path" | sed 's/=.*//'
  fi
}

guest_env_rm() {
  [ "\$#" -gt 0 ] || die "usage: hmux env rm KEY [KEY2 ...]" 2
  hmux_env_path="\$(env_file)"
  for hmux_key in "\$@"; do
    env_key_ok "\$hmux_key" || die "env rm: invalid key '\$hmux_key'" 2
  done
  hmux_env_tmp="\$(mktemp "\${TMPDIR:-/tmp}/hmux-env.XXXXXX")"
  if [ -f "\$hmux_env_path" ]; then
    grep '^export [A-Za-z_][A-Za-z0-9_]*=' "\$hmux_env_path" > "\$hmux_env_tmp" 2>/dev/null || true
  fi
  for hmux_key in "\$@"; do
    grep -v "^export \$hmux_key=" "\$hmux_env_tmp" > "\$hmux_env_tmp.next" || true
    mv -f "\$hmux_env_tmp.next" "\$hmux_env_tmp"
  done
  {
    printf '%s\\n' "# managed by hmux env; KEY='value' lines; edit with hmux env set/rm"
    LC_ALL=C sort -t = -k 1,1 "\$hmux_env_tmp"
  } | env_write
  rm -f "\$hmux_env_tmp"
  env_install_hook
  printf 'OK removed %s from %s\\n' "\$*" "\$hmux_env_path"
}

guest_env_command() {
  hmux_env_sub="\${1:-help}"
  [ "\$#" -gt 0 ] && shift
  case "\$hmux_env_sub" in
    set) guest_env_set "\$@" ;;
    ls|list) guest_env_ls "\$@" ;;
    rm|unset|remove) guest_env_rm "\$@" ;;
    receive) guest_env_receive "\$@" ;;
    path) printf '%s\\n' "\$(env_file)" ;;
    help|--help|-h) env_usage ;;
    *) die "unknown env command '\$hmux_env_sub' (try: hmux env help)" 2 ;;
  esac
}

# ---------------------------------------------------------------------------
# File drop: bytes that arrive typed over the encrypted link (the Mac's
# \`hmux vm push --secret\`, a peer's \`hmux vm push\`), never through a provider
# exec API, an argv, or a control plane. The handshake is \`hmux env receive\`'s
# with HMUX-FILE-* markers, so one sender implementation serves both.
# ---------------------------------------------------------------------------
file_usage() {
  hmux_message fileHelp
}

# Three or four octal digits (600, 0644, 755).
file_mode_ok() {
  case "\$1" in
    [0-7][0-7][0-7]|[0-7][0-7][0-7][0-7]) return 0 ;;
  esac
  return 1
}

file_receive_cleanup() {
  if [ -n "\${hmux_fr_tmp:-}" ]; then rm -f "\$hmux_fr_tmp"; fi
  if [ -n "\${hmux_fr_dir:-}" ]; then rm -rf "\$hmux_fr_dir"; fi
  if [ -n "\${hmux_fr_dog:-}" ]; then kill "\$hmux_fr_dog" 2>/dev/null || true; fi
  if [ "\${hmux_fr_tty:-0}" -eq 1 ]; then stty echo 2>/dev/null || true; fi
  return 0
}

# hmux file receive <path> [--mode <octal>] [--stdin]: turn PTY echo off, print
# HMUX-FILE-READY, read base64 lines up to HMUX-FILE-END, decode in a scratch
# dir (bad input never touches the destination), then land the bytes through a
# temp file in the destination directory and one rename, so a reader never sees
# a partial file and a failed transfer leaves nothing behind. Answers with one
# HMUX-FILE-OK bytes=<n> path=<p> mode=<m> or HMUX-FILE-ERR <reason> line.
# Relative paths are under \$HOME; missing parents are created (0700); the file
# gets the requested mode (default 600); the payload is capped at 256 KiB.
guest_file_receive() {
  hmux_fr_stdin=0
  hmux_fr_mode=600
  hmux_fr_path=""
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --stdin) hmux_fr_stdin=1; shift ;;
      --mode) [ "\$#" -ge 2 ] || { printf 'HMUX-FILE-ERR bad-mode\\n'; exit 2; }; hmux_fr_mode="\$2"; shift 2 ;;
      --mode=*) hmux_fr_mode="\${1#--mode=}"; shift ;;
      --help|-h) file_usage; return 0 ;;
      -*) printf 'HMUX-FILE-ERR usage unknown option %s\\n' "\$1"; exit 2 ;;
      *) if [ -z "\$hmux_fr_path" ]; then hmux_fr_path="\$1"; else printf 'HMUX-FILE-ERR usage one path only\\n'; exit 2; fi; shift ;;
    esac
  done
  [ -n "\$hmux_fr_path" ] || { printf 'HMUX-FILE-ERR usage hmux file receive <path> [--mode <octal>]\\n'; exit 2; }
  file_mode_ok "\$hmux_fr_mode" || { printf 'HMUX-FILE-ERR bad-mode %s\\n' "\$hmux_fr_mode"; exit 2; }
  case "\$hmux_fr_path" in
    /*) ;;
    *) hmux_fr_path="\${HOME:-/root}/\$hmux_fr_path" ;;
  esac
  if [ -d "\$hmux_fr_path" ]; then printf 'HMUX-FILE-ERR is-directory %s\\n' "\$hmux_fr_path"; exit 1; fi
  umask 077
  hmux_fr_tty=0
  if [ "\$hmux_fr_stdin" -eq 0 ] && [ -t 0 ]; then
    if stty -echo 2>/dev/null; then hmux_fr_tty=1; fi
  fi
  hmux_fr_dir="\$(mktemp -d "\${TMPDIR:-/tmp}/hmux-file-recv.XXXXXX")"
  hmux_fr_tmp=""
  # Watchdog, as in env receive: a sender that never finishes must not hold
  # this terminal forever.
  ( hmux_fr_i=0; while [ -d "\$hmux_fr_dir" ] && [ "\$hmux_fr_i" -lt 120 ]; do sleep 1; hmux_fr_i=\$((hmux_fr_i + 1)); done; if [ -d "\$hmux_fr_dir" ]; then kill -TERM \$\$ 2>/dev/null; fi ) </dev/null >/dev/null 2>&1 &
  hmux_fr_dog=\$!
  trap 'file_receive_cleanup' EXIT
  trap 'printf "HMUX-FILE-ERR timeout\\n"; exit 1' TERM
  trap 'printf "HMUX-FILE-ERR interrupted\\n"; exit 1' INT HUP
  printf 'HMUX-FILE-READY\\n'
  hmux_fr_chars=0
  hmux_fr_end=0
  hmux_fr_cr="\$(printf '\\r')"
  while IFS= read -r hmux_fr_line; do
    hmux_fr_line="\${hmux_fr_line%"\$hmux_fr_cr"}"
    if [ "\$hmux_fr_line" = HMUX-FILE-END ]; then hmux_fr_end=1; break; fi
    [ -n "\$hmux_fr_line" ] || continue
    hmux_fr_chars=\$((hmux_fr_chars + \${#hmux_fr_line}))
    # 349528 base64 characters decode to exactly 262144 bytes (256 KiB).
    if [ "\$hmux_fr_chars" -gt 349528 ]; then printf 'HMUX-FILE-ERR too-large\\n'; exit 1; fi
    printf '%s\\n' "\$hmux_fr_line" >> "\$hmux_fr_dir/b64"
  done
  if [ "\$hmux_fr_end" -ne 1 ]; then printf 'HMUX-FILE-ERR eof\\n'; exit 1; fi
  if [ ! -s "\$hmux_fr_dir/b64" ]; then printf 'HMUX-FILE-ERR empty\\n'; exit 1; fi
  if ! base64 -d < "\$hmux_fr_dir/b64" > "\$hmux_fr_dir/payload" 2>/dev/null; then printf 'HMUX-FILE-ERR bad-base64\\n'; exit 1; fi
  hmux_fr_bytes="\$(wc -c < "\$hmux_fr_dir/payload" | tr -d ' ')"
  if [ "\$hmux_fr_bytes" -eq 0 ]; then printf 'HMUX-FILE-ERR empty\\n'; exit 1; fi
  if [ "\$hmux_fr_bytes" -gt 262144 ]; then printf 'HMUX-FILE-ERR too-large\\n'; exit 1; fi
  hmux_fr_parent="\${hmux_fr_path%/*}"
  [ -n "\$hmux_fr_parent" ] || hmux_fr_parent=/
  if [ ! -d "\$hmux_fr_parent" ]; then
    mkdir -p "\$hmux_fr_parent" 2>/dev/null || { printf 'HMUX-FILE-ERR mkdir-failed %s\\n' "\$hmux_fr_parent"; exit 1; }
  fi
  hmux_fr_tmp="\$(mktemp "\$hmux_fr_parent/.hmux-file.XXXXXX" 2>/dev/null)" || { hmux_fr_tmp=""; printf 'HMUX-FILE-ERR write-failed %s\\n' "\$hmux_fr_parent"; exit 1; }
  if cat "\$hmux_fr_dir/payload" > "\$hmux_fr_tmp" 2>/dev/null && chmod "\$hmux_fr_mode" "\$hmux_fr_tmp" 2>/dev/null && mv -f "\$hmux_fr_tmp" "\$hmux_fr_path" 2>/dev/null; then :; else
    printf 'HMUX-FILE-ERR write-failed %s\\n' "\$hmux_fr_path"; exit 1
  fi
  hmux_fr_tmp=""
  printf 'HMUX-FILE-OK bytes=%s path=%s mode=%s\\n' "\$hmux_fr_bytes" "\$hmux_fr_path" "\$hmux_fr_mode"
}

guest_file_command() {
  hmux_file_sub="\${1:-help}"
  [ "\$#" -gt 0 ] && shift
  case "\$hmux_file_sub" in
    receive) guest_file_receive "\$@" ;;
    help|--help|-h) file_usage ;;
    *) die "unknown file command '\$hmux_file_sub' (try: hmux file help)" 2 ;;
  esac
}

# ---------------------------------------------------------------------------
# Terminal verbs in the Mac's spelling (\`hmux vm terminal send|read|wait|close\`
# and \`hmux send|send-key|read-screen\`), on the current target. Local calls
# default to the caller's own terminal (HMUX_TUI_TERMINAL_ID, set by the daemon).
# ---------------------------------------------------------------------------
terminal_usage() {
  hmux_message terminalHelp
}

# Milliseconds for a \`--timeout <seconds>\` (decimals allowed, > 0), or die.
timeout_ms() {
  hmux_ms="\$(awk -v s="\$1" 'BEGIN { if (s !~ /^[0-9]*\\.?[0-9]+\$/ || s + 0 <= 0) exit 1; printf "%d", s * 1000 }')" || die "\${2:-terminal wait}: --timeout takes seconds > 0, got '\$1'" 2
  [ "\$hmux_ms" -ge 1 ] || hmux_ms=1
  printf '%s' "\$hmux_ms"
}

terminal_verb() {
  hmux_tv_verb="\$1"
  hmux_tv_term="\$2"
  shift 2
  [ -n "\$hmux_tv_term" ] || die "terminal \$hmux_tv_verb: a terminal id is required (see hmux terminal list)" 2
  case "\$hmux_tv_verb" in
    rename|move)
      guest_topology_command terminal "\$hmux_tv_verb" "\$hmux_tv_term" "\$@"
      ;;
    send|write)
      hmux_tv_text=""
      hmux_tv_keys=""
      hmux_tv_literal=0
      while [ "\$#" -gt 0 ]; do
        if [ "\$hmux_tv_literal" -eq 1 ]; then hmux_tv_text="\${hmux_tv_text:+\$hmux_tv_text }\$1"; shift; continue; fi
        case "\$1" in
          --) hmux_tv_literal=1; shift ;;
          --keys) [ "\$#" -ge 2 ] || die "terminal send: --keys needs a value (e.g. --keys enter)" 2; hmux_tv_keys="\$2"; shift 2 ;;
          --keys=*) hmux_tv_keys="\${1#--keys=}"; shift ;;
          --json) shift ;;
          *) hmux_tv_text="\${hmux_tv_text:+\$hmux_tv_text }\$1"; shift ;;
        esac
      done
      if [ -z "\$hmux_tv_text" ] && [ -z "\$hmux_tv_keys" ]; then
        die "terminal send: give text and/or --keys (e.g. --keys enter)" 2
      fi
      if [ -n "\$hmux_tv_text" ]; then
        tui terminal "\$hmux_tv_term" write --text "\$hmux_tv_text"
      fi
      if [ -n "\$hmux_tv_keys" ]; then
        set --
        hmux_tv_ifs="\$IFS"
        IFS=,
        for hmux_tv_key in \$hmux_tv_keys; do
          IFS="\$hmux_tv_ifs"
          [ -n "\$hmux_tv_key" ] && set -- "\$@" "\$hmux_tv_key"
          IFS=,
        done
        IFS="\$hmux_tv_ifs"
        [ "\$#" -gt 0 ] || die "terminal send: --keys needs at least one key name" 2
        tui terminal "\$hmux_tv_term" keys "\$@"
      fi
      ;;
    read|screen)
      hmux_tv_json=""
      for hmux_arg in "\$@"; do
        case "\$hmux_arg" in
          --json) hmux_tv_json=--json ;;
          *) die "terminal read: unknown option \$hmux_arg" 2 ;;
        esac
      done
      # shellcheck disable=SC2086
      tui \$hmux_tv_json terminal "\$hmux_tv_term" screen read
      ;;
    wait)
      hmux_tv_pattern=""
      hmux_tv_timeout=30
      hmux_tv_json=0
      while [ "\$#" -gt 0 ]; do
        case "\$1" in
          --pattern) [ "\$#" -ge 2 ] || die "terminal wait: --pattern needs a regex" 2; hmux_tv_pattern="\$2"; shift 2 ;;
          --pattern=*) hmux_tv_pattern="\${1#--pattern=}"; shift ;;
          --timeout) [ "\$#" -ge 2 ] || die "terminal wait: --timeout needs seconds" 2; hmux_tv_timeout="\$2"; shift 2 ;;
          --timeout=*) hmux_tv_timeout="\${1#--timeout=}"; shift ;;
          --json) hmux_tv_json=1; shift ;;
          *) die "terminal wait: unknown option \$1" 2 ;;
        esac
      done
      [ -n "\$hmux_tv_pattern" ] || die "terminal wait: --pattern <regex> is required" 2
      hmux_tv_ms="\$(timeout_ms "\$hmux_tv_timeout")"
      # hmux-tui exits 1 on an unmatched wait (older builds exit 0); either
      # way the printed result says matched false, which is a timeout here.
      if hmux_tv_out="\$(tui --json terminal "\$hmux_tv_term" screen wait --pattern "\$hmux_tv_pattern" --timeout-ms "\$hmux_tv_ms" 2>&1)"; then :; else
        printf '%s\\n' "\$hmux_tv_out" | jq -e '(.value // .) | .matched == false' >/dev/null 2>&1 \\
          || die "terminal wait failed on \$hmux_tv_term: \$hmux_tv_out" 1
      fi
      hmux_tv_matched="\$(printf '%s\\n' "\$hmux_tv_out" | jq -r '(.value // .) | if .matched == true then "true" else "false" end' 2>/dev/null || printf false)"
      if [ "\$hmux_tv_json" -eq 1 ]; then printf '%s\\n' "\$hmux_tv_out"; fi
      if [ "\$hmux_tv_matched" = true ]; then
        [ "\$hmux_tv_json" -eq 1 ] || printf 'OK matched /%s/ on %s\\n' "\$hmux_tv_pattern" "\$hmux_tv_term"
      else
        die "timed out after \${hmux_tv_timeout}s waiting for /\$hmux_tv_pattern/ on \$hmux_tv_term" 1
      fi
      ;;
    wait-exit)
      hmux_tv_timeout=""
      hmux_tv_json=0
      while [ "\$#" -gt 0 ]; do
        case "\$1" in
          --timeout) [ "\$#" -ge 2 ] || die "terminal wait-exit: --timeout needs seconds" 2; hmux_tv_timeout="\$2"; shift 2 ;;
          --timeout=*) hmux_tv_timeout="\${1#--timeout=}"; shift ;;
          --json) hmux_tv_json=1; shift ;;
          *) die "terminal wait-exit: unknown option \$1" 2 ;;
        esac
      done
      set -- terminal "\$hmux_tv_term" process wait
      if [ -n "\$hmux_tv_timeout" ]; then
        hmux_tv_ms="\$(timeout_ms "\$hmux_tv_timeout")"
        set -- "\$@" --timeout-ms "\$hmux_tv_ms"
      fi
      if hmux_tv_out="\$(tui --json "\$@" 2>&1)"; then :; else
        die "terminal wait-exit failed on \$hmux_tv_term: \$hmux_tv_out" 1
      fi
      hmux_tv_state="\$(printf '%s\\n' "\$hmux_tv_out" | jq -r '(.value // .) | if .state == "exited" then ((.outcome // {}) | if .kind == "exit" then "exited code=\\(.code)" elif .kind == "signal" then "exited signal=\\(.signal)" else "exited unknown=\\(.reason // "?")" end) else "pending" end' 2>/dev/null || printf pending)"
      if [ "\$hmux_tv_json" -eq 1 ]; then printf '%s\\n' "\$hmux_tv_out"; else printf '%s\\n' "\$hmux_tv_state"; fi
      case "\$hmux_tv_state" in exited*) ;; *) exit 1 ;; esac
      ;;
    output)
      hmux_tv_after=""
      hmux_tv_max=""
      hmux_tv_json=0
      while [ "\$#" -gt 0 ]; do
        case "\$1" in
          --after) [ "\$#" -ge 2 ] || die "terminal output: --after needs a byte offset" 2; hmux_tv_after="\$2"; shift 2 ;;
          --after=*) hmux_tv_after="\${1#--after=}"; shift ;;
          --max-bytes) [ "\$#" -ge 2 ] || die "terminal output: --max-bytes needs a count" 2; hmux_tv_max="\$2"; shift 2 ;;
          --max-bytes=*) hmux_tv_max="\${1#--max-bytes=}"; shift ;;
          --json) hmux_tv_json=1; shift ;;
          *) die "terminal output: unknown option \$1" 2 ;;
        esac
      done
      case "\$hmux_tv_after" in *[!0-9]*) die "terminal output: --after takes a byte offset, got '\$hmux_tv_after'" 2 ;; esac
      case "\$hmux_tv_max" in *[!0-9]*) die "terminal output: --max-bytes takes 1..4194304, got '\$hmux_tv_max'" 2 ;; esac
      if [ -n "\$hmux_tv_max" ] && { [ "\$hmux_tv_max" -lt 1 ] || [ "\$hmux_tv_max" -gt 4194304 ]; }; then
        die "terminal output: --max-bytes takes 1..4194304, got '\$hmux_tv_max'" 2
      fi
      set -- terminal "\$hmux_tv_term" output read
      [ -z "\$hmux_tv_after" ] || set -- "\$@" --after "\$hmux_tv_after"
      [ -z "\$hmux_tv_max" ] || set -- "\$@" --max-bytes "\$hmux_tv_max"
      if hmux_tv_out="\$(tui --json "\$@" 2>&1)"; then :; else
        die "terminal output failed on \$hmux_tv_term: \$hmux_tv_out" 1
      fi
      if [ "\$hmux_tv_json" -eq 1 ]; then
        printf '%s\\n' "\$hmux_tv_out"
      else
        printf '%s\\n' "\$hmux_tv_out" | jq -j '(.value // .) | .text // ""'
      fi
      ;;
    close)
      tui terminal "\$hmux_tv_term" close
      ;;
    *)
      die "terminal: unknown verb '\$hmux_tv_verb' (send, read, wait, wait-exit, output, close)" 2
      ;;
  esac
}

# \`--terminal <id>\` from the front of "\$@" (the rest is printed back, one per
# line, for the caller to re-split) or the caller's own terminal.
caller_terminal() {
  hmux_ct="\${HMUX_TUI_TERMINAL_ID:-}"
  [ -n "\$hmux_ct" ] || die "no terminal: pass --terminal <term_id> (see hmux terminal list); HMUX_TUI_TERMINAL_ID is set inside daemon terminals" 2
  printf '%s' "\$hmux_ct"
}

local_terminal_alias() {
  hmux_lt_verb="\$1"
  shift
  hmux_lt_term=""
  hmux_lt_json=""
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --terminal) [ "\$#" -ge 2 ] || die "\$hmux_lt_verb: --terminal needs an id" 2; hmux_lt_term="\$2"; shift 2 ;;
      --terminal=*) hmux_lt_term="\${1#--terminal=}"; shift ;;
      --json) hmux_lt_json=--json; shift ;;
      --help|-h) terminal_usage; return 0 ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  [ -n "\$hmux_lt_term" ] || hmux_lt_term="\$(caller_terminal)"
  case "\$hmux_lt_verb" in
    send)
      [ "\$#" -gt 0 ] || die "usage: hmux send [--terminal <id>] <text>" 2
      # shellcheck disable=SC2086
      exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" \$hmux_lt_json terminal "\$hmux_lt_term" write --text "\$*"
      ;;
    send-key)
      [ "\$#" -gt 0 ] || die "usage: hmux send-key [--terminal <id>] <key> [key...]  (enter, tab, escape, up, ctrl+c, ...)" 2
      # shellcheck disable=SC2086
      exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" \$hmux_lt_json terminal "\$hmux_lt_term" keys "\$@"
      ;;
    read-screen)
      [ "\$#" -eq 0 ] || die "usage: hmux read-screen [--terminal <id>] [--json]" 2
      # shellcheck disable=SC2086
      exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" \$hmux_lt_json terminal "\$hmux_lt_term" screen read
      ;;
  esac
}

# The pane a new split should start from when the caller names none: the
# pane showing the caller's terminal, else the focused pane of the focused
# workspace. Read from one snapshot so the answer is the daemon's, not a guess.
default_pane() {
  hmux_dp_snap="\$(tui --json session current snapshot 2>/dev/null)" || die "could not read the session snapshot (is the daemon running?)" 1
  hmux_dp="\$(printf '%s\\n' "\$hmux_dp_snap" | jq -r --arg term "\${HMUX_TUI_TERMINAL_ID:-}" '
    ((.tabs // []) | map(select(\$term != "" and .content_id == \$term)) | .[0].pane_id // "") as \$mine
    | if \$mine != null and \$mine != "" then \$mine else
        (((.workspaces // []) | map(select(.focused == true)) | .[0].id) // ((.workspaces // [])[0].id)) as \$ws
        | (((.screens // []) | map(select(.workspace_id == \$ws and .focused == true)) | .[0].id) // ((.screens // []) | map(select(.workspace_id == \$ws)) | .[0].id)) as \$screen
        | (((.panes // []) | map(select(.screen_id == \$screen and .focused == true)) | .[0].id) // ((.panes // []) | map(select(.screen_id == \$screen)) | .[0].id) // empty)
      end')"
  [ -n "\$hmux_dp" ] || die "no pane to split from; pass --pane <pane_id> (see hmux pane list)" 2
  printf '%s' "\$hmux_dp"
}

${GUEST_HMUX_TOPOLOGY_SHELL}
# ---------------------------------------------------------------------------
# Layouts as data. \`layout export\` turns a daemon workspace into the same
# declarative document the Mac accepts (\`hmux new-workspace --layout\`, hmux.json
# workspaces, \`hmux layout save/open\`); \`layout apply\` builds a workspace from
# one with the public resource verbs. The Mac's \`hmux vm layout …\` runs these.
# ---------------------------------------------------------------------------
layout_usage() {
  hmux_message layoutHelp
}

LAYOUT_RESOLVE_JQ='
  (.workspaces // []) as \$ws
  | (\$ws | map(select(.id == \$sel))) as \$byid
  | if (\$byid | length) == 1 then "ok\\t\\(\$byid[0].id)\\t\\(\$byid[0].name // "")"
    elif \$sel == "" or \$sel == "current" then
      (((\$ws | map(select(.focused == true))) | .[0]) // \$ws[0]) as \$w
      | if \$w == null then "none\\t\\t" else "ok\\t\\(\$w.id)\\t\\(\$w.name // "")" end
    else (\$ws | map(select(.name == \$sel))) as \$byname
      | if (\$byname | length) == 1 then "ok\\t\\(\$byname[0].id)\\t\\(\$byname[0].name // "")"
        elif (\$byname | length) > 1 then "ambiguous\\t\\(\$byname | map(.id) | join(" "))\\t"
        else "missing\\t\\t" end
    end'

# stdin: snapshot. Prints "<ws_id>\\t<name>" or dies (exit 2) naming the problem.
layout_resolve_workspace() {
  hmux_lr="\$(jq -r --arg sel "\$1" "\$LAYOUT_RESOLVE_JQ")"
  case "\$hmux_lr" in
    ok*) printf '%s\\n' "\$hmux_lr" | cut -f 2- ;;
    none*) die "layout: this session has no workspaces yet" 2 ;;
    ambiguous*) die "layout: several workspaces are named '\$1' (\$(printf '%s\\n' "\$hmux_lr" | cut -f 2)); use a ws_… id from \\\`hmux workspace list\\\`" 2 ;;
    *) die "layout: no workspace '\$1' (see hmux workspace list)" 2 ;;
  esac
}

layout_snapshot() {
  if hmux_ls_out="\$(tui --json session current snapshot 2>&1)"; then printf '%s\\n' "\$hmux_ls_out"; else
    die "layout: could not read the session snapshot: \$hmux_ls_out" 1
  fi
}

LAYOUT_EXPORT_JQ='
  def clamp: if . < 0.1 then 0.1 elif . > 0.9 then 0.9 else . end;
  def snap: \$snap[0];
  def term(\$id): ((snap.terminals // []) | map(select(.id == \$id)) | .[0]) // {};
  def browser(\$id): ((snap.browsers // []) | map(select(.id == \$id)) | .[0]) // {};
  def surfaces(\$pid):
    ([ (snap.tabs // [])[] | select(.pane_id == \$pid) ] | sort_by(.index // 0)
     | map(if .content_kind == "browser"
           then ({type: "browser"} + (if (.name // "") != "" then {name: .name} else {} end) + {url: (browser(.content_id).url // "")})
           else ({type: "terminal"} + (if (.name // "") != "" then {name: .name} else {} end)
                 + (if (term(.content_id).cwd // "") != "" then {cwd: term(.content_id).cwd} else {} end)) end))
    | if length == 0 then [{type: "terminal"}] else . end;
  def leaf(\$pid): {pane: {surfaces: surfaces(\$pid)}};
  def node:
    def stack_nodes:
      if length == 0 then leaf("") elif length == 1 then leaf(.[0])
      else {direction: "vertical", split: ((1 / length) | clamp), children: [leaf(.[0]), (.[1:] | stack_nodes)]} end;
    def viewport_nodes:
      if length == 0 then leaf("") elif length == 1 then (.[0].root | node)
      else (map(.width // 1) | add) as \$total
        | {direction: "horizontal", split: (((.[0].width // 1) / (if \$total > 0 then \$total else 1 end)) | clamp),
           children: [(.[0].root | node), (.[1:] | viewport_nodes)]} end;
    if .kind == "leaf" then leaf(.pane_id // "")
    elif .kind == "split" then {direction: (if .direction == "vertical" then "vertical" else "horizontal" end),
                                split: ((.ratio // 0.5) | clamp), children: [(.first | node), (.second | node)]}
    elif .kind == "stack" then ((.pane_ids // []) | stack_nodes)
    elif .kind == "viewport" then ((.columns // []) | viewport_nodes)
    else leaf("") end;
  def add_extra(\$extra):
    if (\$extra | length) == 0 then . elif has("pane") then .pane.surfaces += \$extra else .children[0] |= add_extra(\$extra) end;
  ((snap.screens // []) | map(select(.workspace_id == \$ws)) | sort_by([(if .focused then 0 else 1 end), (.index // 0)])) as \$screens
  | if (\$screens | length) == 0 then error("noscreens") else . end
  | \$screens[0] as \$main
  | ([ \$screens[1:][] as \$s | (snap.panes // [])[] | select(.screen_id == \$s.id) | .id ] | map(surfaces(.)) | add // []) as \$extra
  | if \$raw == 1 then \$main.layout
    else {name: \$wsname, cwd: \$home, layout: ((\$main.layout.root // {kind: "leaf", pane_id: ""}) | node | add_extra(\$extra))} end'

guest_layout_export() {
  hmux_le_sel=""
  hmux_le_raw=0
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --workspace) [ "\$#" -ge 2 ] || die "layout export: --workspace needs a value" 2; hmux_le_sel="\$2"; shift 2 ;;
      --workspace=*) hmux_le_sel="\${1#--workspace=}"; shift ;;
      --raw) hmux_le_raw=1; shift ;;
      --json) shift ;;
      --help|-h) layout_usage; return 0 ;;
      *) die "layout export: unknown option \$1" 2 ;;
    esac
  done
  hmux_le_snap="\$(mktemp "\${TMPDIR:-/tmp}/hmux-layout.XXXXXX")"
  layout_snapshot > "\$hmux_le_snap"
  hmux_le_ws="\$(layout_resolve_workspace "\$hmux_le_sel" < "\$hmux_le_snap")"
  hmux_le_id="\$(printf '%s\\n' "\$hmux_le_ws" | cut -f 1)"
  hmux_le_name="\$(printf '%s\\n' "\$hmux_le_ws" | cut -f 2-)"
  if hmux_le_out="\$(jq -n --slurpfile snap "\$hmux_le_snap" --arg ws "\$hmux_le_id" --arg wsname "\$hmux_le_name" --arg home "\${HOME:-/root}" --argjson raw "\$hmux_le_raw" "\$LAYOUT_EXPORT_JQ" 2>&1)"; then
    rm -f "\$hmux_le_snap"
    printf '%s\\n' "\$hmux_le_out"
  else
    rm -f "\$hmux_le_snap"
    case "\$hmux_le_out" in
      *noscreens*) die "layout export: workspace \$hmux_le_id has no layout yet (no screens); open a terminal in it first" 1 ;;
      *) die "layout export failed: \$hmux_le_out" 1 ;;
    esac
  fi
}

LAYOUT_NORMALIZE_JQ='
  def bad(\$p; \$m): "\\(\$p): \\(\$m)";
  def first_bad: map(select(. != "ok")) | .[0] // "ok";
  def vsurf(\$p):
    if type != "object" then bad(\$p; "surface must be an object")
    elif (has("type") | not) then bad(\$p + ".type"; "surface needs type (terminal, browser, or project)")
    elif ((.type | tostring) as \$t | (\$t == "terminal" or \$t == "browser" or \$t == "project") | not) then bad(\$p + ".type"; "must be terminal, browser, or project")
    elif .type == "browser" and (((.url // "") | tostring) == "") then bad(\$p + ".url"; "browser surface needs url")
    elif has("env") and (.env | type) != "object" then bad(\$p + ".env"; "must be an object of KEY: VALUE strings")
    elif has("command") and (.command | type) != "string" then bad(\$p + ".command"; "must be a string")
    elif has("cwd") and (.cwd | type) != "string" then bad(\$p + ".cwd"; "must be a string")
    else "ok" end;
  def vnode(\$p):
    if type != "object" then bad(\$p; "node must be an object")
    elif has("pane") and has("direction") then bad(\$p; "node must not have both pane and direction")
    elif has("pane") then
      (if (.pane | type) != "object" then bad(\$p + ".pane"; "must be an object")
       elif (.pane.surfaces | type) != "array" or (.pane.surfaces | length) == 0 then bad(\$p + ".pane.surfaces"; "needs at least one surface")
       else ([ .pane.surfaces | to_entries[] | . as \$e | (\$e.value | vsurf(\$p + ".pane.surfaces[\\(\$e.key)]")) ] | first_bad) end)
    elif has("direction") then
      (if ((.direction | tostring) as \$d | (\$d == "horizontal" or \$d == "vertical") | not) then bad(\$p + ".direction"; "must be horizontal or vertical")
       elif (.children | type) != "array" or (.children | length) != 2 then bad(\$p + ".children"; "split needs exactly 2 children")
       elif has("split") and (.split | type) != "number" then bad(\$p + ".split"; "must be a number between 0.1 and 0.9")
       else ([(.children[0] | vnode(\$p + ".children[0]")), (.children[1] | vnode(\$p + ".children[1]"))] | first_bad) end)
    else bad(\$p; "node needs pane or direction") end;
  (if type == "object" and has("workspace") and (.workspace | type) == "object" then {doc: (.workspace + {name: (.name // .workspace.name)}), prefix: "\$.workspace.layout"}
   elif type == "object" and has("layout") then {doc: ., prefix: "\$.layout"}
   elif type == "object" and (has("pane") or has("direction")) then {doc: {layout: .}, prefix: "\$"}
   else {doc: {}, prefix: "\$"} end) as \$n
  | if (\$n.doc.layout // null) == null then {error: "\$: no layout found (expected a layout node, {layout: …}, or {workspace: {layout: …}})"}
    else (\$n.doc.layout | vnode(\$n.prefix)) as \$v
      | if \$v != "ok" then {error: \$v}
        else {ok: {name: (\$n.doc.name // null), cwd: (\$n.doc.cwd // null), env: (\$n.doc.env // {}), layout: \$n.doc.layout}} end
    end'

# Plan: one JSON step per line, in the order the Mac builds a layout — a split
# is made before either half is filled, so nested splits land inside the right
# half. Slot 0 is the root pane (its first surface comes from \`workspace run\`);
# every split creates the next slot. cwd/env are resolved here, once.
LAYOUT_PLAN_JQ='
  def clamp: if . < 0.1 then 0.1 elif . > 0.9 then 0.9 else . end;
  def resolve(\$base): if . == null or . == "" then \$base elif startswith("/") then . elif . == "~" then \$home elif startswith("~/") then \$home + .[1:] else \$base + "/" + . end;
  .env as \$wsenv
  | def surface: (.cwd = ((.cwd // "") | resolve(\$base))) | (.env = (\$wsenv + (.env // {})));
  def first_leaf: if has("pane") then . else (.children[0] | first_leaf) end;
  def build(\$slot; \$next):
    if has("pane") then {steps: [{op: "leaf", slot: \$slot, surfaces: [.pane.surfaces[] | surface]}], next: \$next}
    else \$next as \$new
      | {op: "split", slot: \$slot, new: \$new, direction: .direction, ratio: ((.split // 0.5) | clamp),
         cwd: ((.children[1] | first_leaf | .pane.surfaces[0].cwd // "") | resolve(\$base))} as \$s
      | (.children[0] | build(\$slot; \$new + 1)) as \$a
      | (.children[1] | build(\$new; \$a.next)) as \$b
      | {steps: ([\$s] + \$a.steps + \$b.steps), next: \$b.next} end;
  (.layout | first_leaf | .pane.surfaces[0] | surface) as \$root
  | ({op: "root", surface: \$root, terminal: (\$root.type == "terminal")}, ((.layout | build(0; 1)).steps[]))'

layout_tui_json() {
  hmux_ltj_label="\$1"
  shift
  if [ -n "\${hmux_la_first_revision:-}" ]; then
    set -- --expected-revision "\$hmux_la_first_revision" "\$@"
    hmux_la_first_revision=""
  fi
  if hmux_out="\$(tui --json "\$@" 2>&1)"; then :; else die "layout apply: \$hmux_ltj_label failed: \$hmux_out" 1; fi
}

layout_slot_set() {
  printf '%s' "\$2" > "\$hmux_la_scratch/slot.\$1.pane"
  printf '%s' "\$3" > "\$hmux_la_scratch/slot.\$1.ph"
  printf '%s' "\$4" > "\$hmux_la_scratch/slot.\$1.done"
}
layout_slot_get() { cat "\$hmux_la_scratch/slot.\$1.\$2" 2>/dev/null || true; }

# Start a terminal surface: \$1 = pane id ("" = the workspace root via
# \`workspace run\`), \$2 = surface JSON. Sets hmux_new_pane/term/tab.
layout_spawn_terminal() {
  hmux_st_pane="\$1"
  hmux_st_surface="\$2"
  hmux_st_cwd="\$(printf '%s\\n' "\$hmux_st_surface" | jq -r '.cwd // empty')"
  hmux_st_name="\$(printf '%s\\n' "\$hmux_st_surface" | jq -r '.name // empty')"
  hmux_st_pairs="\$(printf '%s\\n' "\$hmux_st_surface" | jq -r '(.env // {}) | to_entries[] | "\\(.key)=\\(.value | tostring)"')"
  set --
  if [ -n "\$hmux_st_cwd" ]; then set -- "\$@" --cwd "\$hmux_st_cwd"; fi
  if [ -n "\$hmux_st_name" ]; then set -- "\$@" --name "\$hmux_st_name"; fi
  set -- "\$@" --
  if [ -n "\$hmux_st_pairs" ]; then
    set -- "\$@" env
    while IFS= read -r hmux_st_pair; do
      [ -n "\$hmux_st_pair" ] || continue
      env_key_ok "\${hmux_st_pair%%=*}" || die "layout apply: invalid env key '\${hmux_st_pair%%=*}' (letters, digits and _ only)" 2
      set -- "\$@" "\$hmux_st_pair"
    done <<EOF
\$hmux_st_pairs
EOF
  fi
  set -- "\$@" bash -l
  # \`--on-exit keep\`: a layout pane whose command exits keeps its tab and final
  # screen instead of vanishing from the layout the person asked for.
  if [ -z "\$hmux_st_pane" ]; then
    layout_tui_json "workspace \$hmux_la_ws run" workspace "\$hmux_la_ws" run --on-exit keep "\$@"
  else
    layout_tui_json "pane \$hmux_st_pane run" pane "\$hmux_st_pane" run --on-exit keep "\$@"
  fi
  hmux_new_pane="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .pane_id // empty')"
  hmux_new_term="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .terminal_id // empty')"
  hmux_new_tab="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .tab_id // empty')"
  [ -n "\$hmux_new_term" ] || die "layout apply: run returned no terminal id: \$hmux_out" 1
  [ -n "\$hmux_new_pane" ] || hmux_new_pane="\$hmux_st_pane"
  [ -n "\$hmux_new_pane" ] || die "layout apply: run returned no pane id: \$hmux_out" 1
}

# A browser tab in pane \$1 for surface \$2. Returns 1 (after a warning) when the
# daemon cannot open browsers here, so the caller keeps the pane's shell.
layout_create_browser() {
  hmux_cb_url="\$(printf '%s\\n' "\$2" | jq -r '.url // empty')"
  hmux_cb_name="\$(printf '%s\\n' "\$2" | jq -r '.name // empty')"
  set -- pane "\$1" tab create browser --url "\$hmux_cb_url"
  if [ -n "\$hmux_cb_name" ]; then set -- "\$@" --name "\$hmux_cb_name"; fi
  if hmux_out="\$(tui --json "\$@" 2>&1)"; then :; else
    warn "browser surface \$hmux_cb_url could not be opened in pane \$1 (the pane keeps its shell): \$hmux_out"
    return 1
  fi
  hmux_new_tab="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .tab_id // empty')"
  hmux_new_browser="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .browser_id // empty')"
  return 0
}

# Type a surface's \`command\` into a terminal that was just started: wait for a
# prompt (bounded; typing early is still safe — the PTY buffers it), then the
# text and Enter, exactly what the Mac does with sendInputWhenReady.
layout_type_command() {
  tui --json terminal "\$1" screen wait --pattern 'λ|\\\$ \$|# \$' --timeout-ms 8000 >/dev/null 2>&1 || true
  tui --json terminal "\$1" write --text "\$2" >/dev/null 2>&1 || warn "could not type into \$1"
  tui --json terminal "\$1" keys enter >/dev/null 2>&1 || warn "could not press enter in \$1"
}

layout_record() {
  # \$1 pane, \$2 surface json, \$3 terminal id, \$4 browser id, \$5 tab id
  jq -cn --arg pane "\$1" --argjson s "\$2" --arg term "\$3" --arg browser "\$4" --arg tab "\$5" '
    {pane_id: \$pane, surface: ({type: \$s.type}
      + (if (\$s.name // "") != "" then {name: \$s.name} else {} end)
      + (if \$term != "" then {terminal_id: \$term} else {} end)
      + (if \$browser != "" then {browser_id: \$browser} else {} end)
      + {tab_id: \$tab})}' >> "\$hmux_la_scratch/summary.jsonl"
}

layout_resolve_path() {
  case "\${2:-}" in
    '') printf '%s' "\$1" ;;
    /*) printf '%s' "\$2" ;;
    '~') printf '%s' "\${HOME:-/root}" ;;
    '~/'*) printf '%s%s' "\${HOME:-/root}" "\${2#\\~}" ;;
    *) printf '%s/%s' "\$1" "\$2" ;;
  esac
}

guest_layout_apply() {
  hmux_la_ws_sel=""
  hmux_la_name=""
  hmux_la_cwd=""
  hmux_la_json=0
  hmux_la_file=""
  hmux_la_reuse=0
  hmux_la_first_revision=""
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --workspace) [ "\$#" -ge 2 ] || die "layout apply: --workspace needs a value" 2; hmux_la_ws_sel="\$2"; shift 2 ;;
      --workspace=*) hmux_la_ws_sel="\${1#--workspace=}"; shift ;;
      --name) [ "\$#" -ge 2 ] || die "layout apply: --name needs a value" 2; hmux_la_name="\$2"; shift 2 ;;
      --name=*) hmux_la_name="\${1#--name=}"; shift ;;
      --cwd) [ "\$#" -ge 2 ] || die "layout apply: --cwd needs a value" 2; hmux_la_cwd="\$2"; shift 2 ;;
      --cwd=*) hmux_la_cwd="\${1#--cwd=}"; shift ;;
      --json) hmux_la_json=1; shift ;;
      --reuse) hmux_la_reuse=1; shift ;;
      --help|-h) layout_usage; return 0 ;;
      -) hmux_la_file=-; shift ;;
      -*) die "layout apply: unknown option \$1" 2 ;;
      *) [ -z "\$hmux_la_file" ] || die "layout apply: one document at a time" 2; hmux_la_file="\$1"; shift ;;
    esac
  done
  if [ -z "\$hmux_la_file" ]; then
    if [ -t 0 ]; then die "usage: hmux layout apply [--workspace <ws>|--name <n>] [--cwd <dir>] [--json] <file>|-   (or pipe the document in)" 2; fi
    hmux_la_file=-
  fi
  if [ -n "\$hmux_la_ws_sel" ] && [ -n "\$hmux_la_name" ]; then
    die "layout apply: --workspace (build in an existing empty workspace) and --name (create one) are two different targets; pass one" 2
  fi
  hmux_la_scratch="\$(mktemp -d "\${TMPDIR:-/tmp}/hmux-layout.XXXXXX")"
  trap 'rm -rf "\$hmux_la_scratch"' EXIT INT TERM
  : > "\$hmux_la_scratch/warnings"
  : > "\$hmux_la_scratch/summary.jsonl"
  if [ "\$hmux_la_file" = - ]; then
    cat > "\$hmux_la_scratch/doc.json"
  else
    [ -f "\$hmux_la_file" ] || die "layout apply: no such file \$hmux_la_file" 2
    cat "\$hmux_la_file" > "\$hmux_la_scratch/doc.json"
  fi
  if hmux_la_norm="\$(jq -c "\$LAYOUT_NORMALIZE_JQ" "\$hmux_la_scratch/doc.json" 2>&1)"; then :; else
    die "layout apply: the document is not valid JSON: \$hmux_la_norm" 2
  fi
  hmux_la_err="\$(printf '%s\\n' "\$hmux_la_norm" | jq -r '.error // empty')"
  [ -z "\$hmux_la_err" ] || die "layout apply: invalid layout document at \$hmux_la_err" 2
  printf '%s\\n' "\$hmux_la_norm" | jq -c '.ok' > "\$hmux_la_scratch/norm.json"

  hmux_la_home="\${HOME:-/root}"
  [ -n "\$hmux_la_cwd" ] || hmux_la_cwd="\$(jq -r '.cwd // empty' "\$hmux_la_scratch/norm.json")"
  hmux_la_base="\$(layout_resolve_path "\$hmux_la_home" "\$hmux_la_cwd")"
  [ -n "\$hmux_la_name" ] || hmux_la_name="\$(jq -r '.name // empty' "\$hmux_la_scratch/norm.json")"
  [ -n "\$hmux_la_name" ] || hmux_la_name=layout
  jq -c --arg base "\$hmux_la_base" --arg home "\$hmux_la_home" "\$LAYOUT_PLAN_JQ" "\$hmux_la_scratch/norm.json" > "\$hmux_la_scratch/plan.jsonl" \\
    || die "layout apply: could not plan the layout" 1

  if [ "\$hmux_la_reuse" = 1 ] && [ -z "\$hmux_la_ws_sel" ]; then
    hmux_la_created="\$(guest_workspace_get_or_create "\$hmux_la_name" 1)" || return \$?
    [ "\$(printf '%s\\n' "\$hmux_la_created" | jq -r .existing)" != true ] || die_message 1 workspacePreparationChanged
    hmux_la_ws_sel="\$(printf '%s\\n' "\$hmux_la_created" | jq -er '(.value // .) | .id // .workspace_id')" || die_message 1 workspaceReuseUnavailable
  fi

  # The target: an existing EMPTY workspace, or a new one.
  hmux_la_root_pane=""
  hmux_la_root_ph=""
  if [ -n "\$hmux_la_ws_sel" ]; then
    layout_snapshot > "\$hmux_la_scratch/snap.json"
    if [ "\$hmux_la_reuse" = 1 ]; then
      hmux_la_first_revision="\$(jq -er '(.cursor.revision // .session.revision) | select(type == "string" and test("^[0-9]+\$"))' "\$hmux_la_scratch/snap.json")" || die_message 1 workspaceReuseUnavailable
    fi
    hmux_la_resolved="\$(layout_resolve_workspace "\$hmux_la_ws_sel" < "\$hmux_la_scratch/snap.json")"
    hmux_la_ws="\$(printf '%s\\n' "\$hmux_la_resolved" | cut -f 1)"
    hmux_la_ws_name="\$(printf '%s\\n' "\$hmux_la_resolved" | cut -f 2-)"
    hmux_la_count="\$(jq -r --arg ws "\$hmux_la_ws" '
      [ (.screens // [])[] | select(.workspace_id == \$ws) | .id ] as \$screens
      | [ (.panes // [])[] | select(.screen_id as \$sid | \$screens | index(\$sid)) ] | length' "\$hmux_la_scratch/snap.json")"
    [ "\$hmux_la_count" = 0 ] || die "layout apply: workspace \$hmux_la_ws already has a layout (\$hmux_la_count pane\$([ "\$hmux_la_count" = 1 ] || printf s)); pass --name to build a new workspace instead, or empty it first (hmux workspace \$hmux_la_ws close)" 1
  else
    if hmux_out="\$(tui --json workspace create --empty --name "\$hmux_la_name" 2>&1)"; then :; else
      # Older daemons have no --empty; their starter terminal becomes the root placeholder.
      if hmux_out="\$(tui --json workspace create --name "\$hmux_la_name" 2>&1)"; then :; else
        die "layout apply: workspace create failed: \$hmux_out" 1
      fi
    fi
    hmux_la_ws="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .workspace_id // .id // empty')"
    [ -n "\$hmux_la_ws" ] || die "layout apply: workspace create returned no workspace id: \$hmux_out" 1
    hmux_la_root_pane="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .pane_id // empty')"
    hmux_la_root_ph="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .terminal_id // empty')"
    hmux_la_ws_name="\$hmux_la_name"
  fi

  hmux_la_focus=""
  hmux_la_first_pane=""
  # The plan is read on fd 3 so nothing a step runs can eat it from stdin.
  while IFS= read -r hmux_step <&3; do
    hmux_op="\$(printf '%s\\n' "\$hmux_step" | jq -r '.op')"
    case "\$hmux_op" in
      root)
        if [ -n "\$hmux_la_root_pane" ]; then
          layout_slot_set 0 "\$hmux_la_root_pane" "\$hmux_la_root_ph" ""
        elif [ "\$(printf '%s\\n' "\$hmux_step" | jq -r 'if .terminal then 1 else 0 end')" = 1 ]; then
          layout_spawn_terminal "" "\$(printf '%s\\n' "\$hmux_step" | jq -c '.surface')"
          layout_slot_set 0 "\$hmux_new_pane" "" "\$hmux_new_term \$hmux_new_tab"
        else
          layout_spawn_terminal "" '{"type":"terminal"}'
          layout_slot_set 0 "\$hmux_new_pane" "\$hmux_new_term" ""
        fi
        ;;
      split)
        hmux_sp_slot="\$(printf '%s\\n' "\$hmux_step" | jq -r '.slot')"
        hmux_sp_new="\$(printf '%s\\n' "\$hmux_step" | jq -r '.new')"
        hmux_sp_dir="\$(printf '%s\\n' "\$hmux_step" | jq -r 'if .direction == "vertical" then "--down" else "--right" end')"
        # The document stores the first child's share. A right/down pane split
        # asks the daemon for the NEW (second) pane's share instead.
        hmux_sp_ratio="\$(printf '%s\\n' "\$hmux_step" | jq -r '1 - .ratio')"
        hmux_sp_cwd="\$(printf '%s\\n' "\$hmux_step" | jq -r '.cwd // empty')"
        hmux_sp_pane="\$(layout_slot_get "\$hmux_sp_slot" pane)"
        [ -n "\$hmux_sp_pane" ] || die "layout apply: internal error: no pane for slot \$hmux_sp_slot" 1
        set -- pane "\$hmux_sp_pane" split "\$hmux_sp_dir" --ratio "\$hmux_sp_ratio"
        if [ -n "\$hmux_sp_cwd" ]; then set -- "\$@" --cwd "\$hmux_sp_cwd"; fi
        layout_tui_json "pane \$hmux_sp_pane split" "\$@"
        hmux_new_pane="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .pane_id // empty')"
        hmux_new_term="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .terminal_id // empty')"
        [ -n "\$hmux_new_pane" ] || die "layout apply: pane \$hmux_sp_pane split returned no pane id: \$hmux_out" 1
        layout_slot_set "\$hmux_sp_new" "\$hmux_new_pane" "\$hmux_new_term" ""
        ;;
      leaf)
        hmux_lf_slot="\$(printf '%s\\n' "\$hmux_step" | jq -r '.slot')"
        hmux_lf_pane="\$(layout_slot_get "\$hmux_lf_slot" pane)"
        hmux_lf_ph="\$(layout_slot_get "\$hmux_lf_slot" ph)"
        hmux_lf_done="\$(layout_slot_get "\$hmux_lf_slot" done)"
        [ -n "\$hmux_lf_pane" ] || die "layout apply: internal error: no pane for slot \$hmux_lf_slot" 1
        [ -n "\$hmux_la_first_pane" ] || hmux_la_first_pane="\$hmux_lf_pane"
        hmux_lf_count="\$(printf '%s\\n' "\$hmux_step" | jq -r '.surfaces | length')"
        hmux_lf_i=0
        while [ "\$hmux_lf_i" -lt "\$hmux_lf_count" ]; do
          hmux_lf_surface="\$(printf '%s\\n' "\$hmux_step" | jq -c ".surfaces[\$hmux_lf_i]")"
          hmux_lf_type="\$(printf '%s\\n' "\$hmux_lf_surface" | jq -r '.type')"
          hmux_lf_cmd="\$(printf '%s\\n' "\$hmux_lf_surface" | jq -r '.command // empty')"
          hmux_lf_focus="\$(printf '%s\\n' "\$hmux_lf_surface" | jq -r 'if .focus == true then 1 else 0 end')"
          if [ "\$hmux_lf_i" -eq 0 ] && [ -n "\$hmux_lf_done" ]; then
            # The root's first terminal already exists (made by \`workspace run\`).
            hmux_lf_term="\${hmux_lf_done%% *}"
            hmux_lf_tab="\${hmux_lf_done#* }"
            layout_record "\$hmux_lf_pane" "\$hmux_lf_surface" "\$hmux_lf_term" "" "\$hmux_lf_tab"
            if [ -n "\$hmux_lf_cmd" ]; then layout_type_command "\$hmux_lf_term" "\$hmux_lf_cmd"; fi
          else
            case "\$hmux_lf_type" in
              terminal)
                layout_spawn_terminal "\$hmux_lf_pane" "\$hmux_lf_surface"
                layout_record "\$hmux_lf_pane" "\$hmux_lf_surface" "\$hmux_new_term" "" "\$hmux_new_tab"
                if [ "\$hmux_lf_i" -eq 0 ] && [ -n "\$hmux_lf_ph" ]; then
                  tui --json terminal "\$hmux_lf_ph" close >/dev/null 2>&1 || warn "could not close placeholder terminal \$hmux_lf_ph"
                  hmux_lf_ph=""
                fi
                if [ -n "\$hmux_lf_cmd" ]; then layout_type_command "\$hmux_new_term" "\$hmux_lf_cmd"; fi
                ;;
              browser)
                if layout_create_browser "\$hmux_lf_pane" "\$hmux_lf_surface"; then
                  layout_record "\$hmux_lf_pane" "\$hmux_lf_surface" "" "\$hmux_new_browser" "\$hmux_new_tab"
                  if [ "\$hmux_lf_i" -eq 0 ] && [ -n "\$hmux_lf_ph" ]; then
                    tui --json terminal "\$hmux_lf_ph" close >/dev/null 2>&1 || warn "could not close placeholder terminal \$hmux_lf_ph"
                    hmux_lf_ph=""
                  fi
                fi
                ;;
              *)
                warn "project surfaces are Mac-only; skipped one at pane \$hmux_lf_pane"
                ;;
            esac
          fi
          if [ "\$hmux_lf_focus" = 1 ]; then hmux_la_focus="\$hmux_lf_pane"; fi
          hmux_lf_i=\$((hmux_lf_i + 1))
        done
        ;;
    esac
  done 3< "\$hmux_la_scratch/plan.jsonl"

  [ -n "\$hmux_la_focus" ] || hmux_la_focus="\$hmux_la_first_pane"
  if [ -n "\$hmux_la_focus" ]; then
    tui --json pane "\$hmux_la_focus" focus >/dev/null 2>&1 || warn "could not focus pane \$hmux_la_focus"
  fi
  hmux_la_summary="\$(jq -s --arg ws "\$hmux_la_ws" --arg name "\$hmux_la_ws_name" --rawfile w "\$hmux_la_scratch/warnings" '
    reduce .[] as \$e ([];
      if any(.[]; .pane_id == \$e.pane_id) then map(if .pane_id == \$e.pane_id then .surfaces += [\$e.surface] else . end)
      else . + [{pane_id: \$e.pane_id, surfaces: [\$e.surface]}] end)
    | {workspace_id: \$ws, workspace_name: \$name, panes: ., warnings: (\$w | split("\\n") | map(select(. != "")))}' "\$hmux_la_scratch/summary.jsonl")"
  if [ "\$hmux_la_json" -eq 1 ]; then
    printf '%s\\n' "\$hmux_la_summary"
  else
    printf 'OK workspace=%s name=%s panes=%s surfaces=%s\\n' "\$hmux_la_ws" "\$hmux_la_ws_name" \\
      "\$(printf '%s\\n' "\$hmux_la_summary" | jq -r '.panes | length')" \\
      "\$(printf '%s\\n' "\$hmux_la_summary" | jq -r '[.panes[].surfaces | length] | add // 0')"
  fi
}

guest_layout_command() {
  hmux_layout_sub="\${1:-help}"
  [ "\$#" -gt 0 ] && shift
  case "\$hmux_layout_sub" in
    export|get) guest_layout_export "\$@" ;;
    apply|open) guest_layout_apply "\$@" ;;
    help|--help|-h) layout_usage ;;
    *) die "unknown layout command '\$hmux_layout_sub' (try: hmux layout help)" 2 ;;
  esac
}

# ---------------------------------------------------------------------------
# Peers.
# ---------------------------------------------------------------------------
peer_file() { printf '%s/%s.json' "\$PEERS_DIR" "\$1"; }

# Establish (or reuse) the headless link to a peer; prints the peer's local mux
# socket path. The link subprocess outlives this command (nohup) so later verbs
# reuse it. Route files are written by the Mac's \`hmux vm link\`.
ensure_link() {
  peer="\$1"
  file="\$(peer_file "\$peer")"
  if [ ! -f "\$file" ]; then
    reflection_discover_peer "\$peer" || die_message 2 missingLink "\$peer" "\$hmux_rd_reason"
  fi
  mkdir -p "\$LINKS_DIR"
  sock_file="\$LINKS_DIR/\$peer.sock-path"
  pid_file="\$LINKS_DIR/\$peer.pid"
  if [ -f "\$sock_file" ] && [ -f "\$pid_file" ] && kill -0 "\$(cat "\$pid_file")" 2>/dev/null; then
    sock="\$(cat "\$sock_file")"
    if [ -S "\$sock" ]; then printf '%s' "\$sock"; return 0; fi
  fi
  route="\$(jq -r .route "\$file")"
  [ -n "\$route" ] && [ "\$route" != null ] || die_message 2 invalidPeer "\$file"
  invite="\$(jq -r '.invite // empty' "\$file")"
  out_file="\$LINKS_DIR/\$peer.connect.jsonl"
  : > "\$out_file"
  set -- remote connect "\$route" --headless --json \\
    --device-name "vm-\$(hostname 2>/dev/null || echo guest)" \\
    --state-dir "\$HMUX_GUEST_HOME/peer-devices"
  if [ -n "\$invite" ]; then
    invite_file="\$LINKS_DIR/\$peer.invite"
    umask 077
    printf '%s' "\$invite" > "\$invite_file"
    set -- "\$@" --invite-file "\$invite_file"
  fi
  umask 077
  connect_dir="\$(mktemp -d "\$LINKS_DIR/.connect.XXXXXX")"
  link_pid=""; relay_pid=""; link_ready=false
  trap 'if [ "\$link_ready" != true ]; then
    [ -z "\$link_pid" ] || kill "\$link_pid" 2>/dev/null || true
    [ -z "\$relay_pid" ] || kill "\$relay_pid" 2>/dev/null || true
  fi
  rm -rf "\$connect_dir"' EXIT
  trap 'exit 130' HUP INT TERM
  mkfifo "\$connect_dir/events" "\$connect_dir/ready"
  exec 3<> "\$connect_dir/ready"
  nohup "\$HMUX_TUI_BIN" "\$@" 3>&- > "\$connect_dir/events" 2>>"\$LINKS_DIR/\$peer.log" &
  link_pid="\$!"
  printf '%s' "\$link_pid" > "\$pid_file"
  nohup /bin/sh -c '
    out_file="\$1"; announced=false
    while IFS= read -r event; do
      printf "%s\\n" "\$event" >> "\$out_file"
      [ "\$announced" = false ] || continue
      socket="\$(printf "%s\\n" "\$event" | jq -r "\$2" 2>/dev/null || true)"
      if [ -n "\$socket" ] && [ -S "\$socket" ]; then
        printf "%s\\n" "\$socket" >&3
        exec 3>&-
        announced=true
      fi
    done
    [ "\$announced" = true ] || printf "\\n" >&3
  ' sh "\$out_file" 'select(.event=="connection-snapshot") | .local_socket // empty' < "\$connect_dir/events" > /dev/null 2>>"\$LINKS_DIR/\$peer.log" &
  relay_pid="\$!"
  printf '%s' "\$relay_pid" > "\$LINKS_DIR/\$peer.events.pid"
  if ! sock="\$(/bin/bash -c 'IFS= read -r -t 30 socket <&3 && printf "%s" "\$socket"')"; then
    die_message 3 linkTimeout "\$peer" "\$LINKS_DIR/\$peer.log"
  fi
  exec 3>&-
  [ -n "\$sock" ] && [ -S "\$sock" ] || die_message 3 linkExited "\$peer" "\$LINKS_DIR/\$peer.log"
  printf '%s' "\$sock" > "\$sock_file"
  jq 'del(.invite)' "\$file" > "\$connect_dir/peer.json" && mv "\$connect_dir/peer.json" "\$file"
  if [ -n "\$invite" ]; then rm -f "\$invite_file"; fi
  link_ready=true
  printf '%s' "\$sock"
}

# The workspace a durable command runs in on the current target: the current
# one, or a fresh \`main\` when the session has none (a brand-new machine).
target_workspace() {
  if tui workspace current show >/dev/null 2>&1; then printf 'current'; return 0; fi
  hmux_tw_creation="\$(tui --json workspace create --name main 2>/dev/null)" || die_message 3 workspaceCreateFailed
  hmux_tw_created="\$(printf '%s' "\$hmux_tw_creation" | jq -r '(.value // .) | .workspace_id // .id // .workspace.id // empty')" || die_message 3 workspaceMissingID
  [ -n "\$hmux_tw_created" ] || die_message 3 workspaceMissingID
  printf '%s' "\$hmux_tw_created"
}

peer_usage() {
  hmux_message peerHelp
}

# agent_wait_terminal <terminal> <timeout-seconds|""> <output 0|1> <json 0|1> <label> <agent> <workspace>:
# block on the daemon's process wait in slices of at most 30 s until the agent
# exits or the timeout passes; with output, page the terminal's stream from
# offset 0. Prints the outcome (or the JSON summary) and returns the agent's
# exit code; a signal or a timeout returns 1 and says so on stderr.
agent_wait_terminal() {
  hmux_aw_term="\$1"
  hmux_aw_timeout="\$2"
  hmux_aw_output="\$3"
  hmux_aw_json="\$4"
  hmux_aw_where="\$5"
  hmux_aw_agent="\$6"
  hmux_aw_ws="\$7"
  hmux_aw_total=""
  [ -z "\$hmux_aw_timeout" ] || hmux_aw_total="\$(timeout_ms "\$hmux_aw_timeout" "agent --wait")"
  hmux_aw_elapsed=0
  hmux_aw_state=pending
  hmux_aw_out='{}'
  while :; do
    hmux_aw_slice=30000
    if [ -n "\$hmux_aw_total" ]; then
      hmux_aw_left=\$((hmux_aw_total - hmux_aw_elapsed))
      [ "\$hmux_aw_left" -gt 0 ] || break
      [ "\$hmux_aw_left" -ge "\$hmux_aw_slice" ] || hmux_aw_slice="\$hmux_aw_left"
    fi
    if hmux_aw_out="\$(tui --json terminal "\$hmux_aw_term" process wait --timeout-ms "\$hmux_aw_slice" 2>&1)"; then :; else
      die "agent --wait: process wait failed for \$hmux_aw_term on \$hmux_aw_where: \$hmux_aw_out" 1
    fi
    hmux_aw_state="\$(printf '%s\\n' "\$hmux_aw_out" | jq -r '(.value // .) | .state // "pending"' 2>/dev/null || printf pending)"
    [ "\$hmux_aw_state" != exited ] || break
    hmux_aw_elapsed=\$((hmux_aw_elapsed + hmux_aw_slice))
  done
  hmux_aw_line="\$(printf '%s\\n' "\$hmux_aw_out" | jq -r '(.value // .) | if .state == "exited" then ((.outcome // {}) | if .kind == "exit" then "exited code=\\(.code)" elif .kind == "signal" then "exited signal=\\(.signal)" else "exited unknown=\\(.reason // "?")" end) else "pending" end' 2>/dev/null || printf pending)"
  hmux_aw_code=1
  case "\$hmux_aw_line" in "exited code="*) hmux_aw_code="\${hmux_aw_line#exited code=}" ;; esac
  case "\$hmux_aw_code" in ''|*[!0-9]*) hmux_aw_code=1 ;; esac
  hmux_aw_text="\$(mktemp "\${TMPDIR:-/tmp}/hmux-agent-out.XXXXXX")"
  hmux_aw_after=0
  if [ "\$hmux_aw_output" -eq 1 ]; then
    while :; do
      if hmux_aw_page="\$(tui --json terminal "\$hmux_aw_term" output read --after "\$hmux_aw_after" 2>&1)"; then :; else
        rm -f "\$hmux_aw_text"
        die "agent --output: output read failed for \$hmux_aw_term on \$hmux_aw_where: \$hmux_aw_page" 1
      fi
      if [ "\$hmux_aw_json" -eq 1 ]; then
        printf '%s\\n' "\$hmux_aw_page" | jq -j '(.value // .) | .text // ""' >> "\$hmux_aw_text" 2>/dev/null || true
      else
        printf '%s\\n' "\$hmux_aw_page" | jq -j '(.value // .) | .text // ""' 2>/dev/null || true
      fi
      hmux_aw_next="\$(printf '%s\\n' "\$hmux_aw_page" | jq -r '(.value // .) | (.next_offset // empty)' 2>/dev/null || true)"
      hmux_aw_complete="\$(printf '%s\\n' "\$hmux_aw_page" | jq -r '(.value // .) | if .complete == true then 1 else 0 end' 2>/dev/null || printf 1)"
      case "\$hmux_aw_next" in ''|*[!0-9]*) hmux_aw_next="\$hmux_aw_after" ;; esac
      [ "\$hmux_aw_next" -gt "\$hmux_aw_after" ] || hmux_aw_complete=1
      hmux_aw_after="\$hmux_aw_next"
      [ "\$hmux_aw_complete" != 1 ] || break
    done
  fi
  if [ "\$hmux_aw_json" -eq 1 ]; then
    jq -n --arg term "\$hmux_aw_term" --arg ws "\$hmux_aw_ws" --arg machine "\$hmux_aw_where" --arg agent "\$hmux_aw_agent" \\
      --arg state "\$hmux_aw_state" --arg line "\$hmux_aw_line" --argjson output "\$hmux_aw_output" --argjson after "\$hmux_aw_after" \\
      --rawfile text "\$hmux_aw_text" '
      {terminal_id: \$term, workspace_id: \$ws, machine: \$machine, agent: \$agent, state: \$state,
       exit_code: ((\$line | capture("^exited code=(?<c>[0-9]+)\$")? | .c | tonumber) // null),
       signal: ((\$line | capture("^exited signal=(?<s>[0-9]+)\$")? | .s | tonumber) // null)}
      + (if \$output == 1 then {output: \$text, next_offset: \$after} else {} end)'
  elif [ "\$hmux_aw_output" -eq 0 ]; then
    printf '%s\\n' "\$hmux_aw_line"
  fi
  rm -f "\$hmux_aw_text"
  case "\$hmux_aw_line" in
    "exited code="*) return "\$hmux_aw_code" ;;
    exited*) printf '%s\\n' "hmux: agent \$hmux_aw_agent on \$hmux_aw_where ended by a signal (\$hmux_aw_line, terminal \$hmux_aw_term)" >&2; return 1 ;;
    *) printf '%s\\n' "hmux: agent \$hmux_aw_agent on \$hmux_aw_where is still running after \${hmux_aw_timeout}s (terminal \$hmux_aw_term; hmux vm terminal wait-exit \$hmux_aw_where \$hmux_aw_term, or hmux vm terminal output \$hmux_aw_where \$hmux_aw_term --after \$hmux_aw_after)" >&2; return 1 ;;
  esac
}

# \`hmux vm agent <peer> --agent <a> [--name n] [--cwd d] [--workspace ws] [--wait [--output] [--timeout s]] -- <args>\`:
# a durable terminal on the peer running the peer's own \`hmux agent\`, so the
# peer's CodeRouter config and machine env apply and the prompt rules match.
# --wait blocks until that terminal's process exits (exit code = the agent's);
# --output then prints its whole terminal stream; --timeout caps the wait.
peer_agent() {
  hmux_pa_peer="\$1"
  shift
  hmux_pa_agent=""
  hmux_pa_name=""
  hmux_pa_cwd=""
  hmux_pa_ws=""
  hmux_pa_wait=0
  hmux_pa_output=0
  hmux_pa_timeout=""
  hmux_pa_json=0
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --agent) [ "\$#" -ge 2 ] || die "vm agent: --agent needs claude, codex, opencode, or pi" 2; hmux_pa_agent="\$2"; shift 2 ;;
      --agent=*) hmux_pa_agent="\${1#--agent=}"; shift ;;
      --name) [ "\$#" -ge 2 ] || die "vm agent: --name needs a value" 2; hmux_pa_name="\$2"; shift 2 ;;
      --name=*) hmux_pa_name="\${1#--name=}"; shift ;;
      --cwd) [ "\$#" -ge 2 ] || die "vm agent: --cwd needs a value" 2; hmux_pa_cwd="\$2"; shift 2 ;;
      --cwd=*) hmux_pa_cwd="\${1#--cwd=}"; shift ;;
      --workspace) [ "\$#" -ge 2 ] || die "vm agent: --workspace needs a value" 2; hmux_pa_ws="\$2"; shift 2 ;;
      --workspace=*) hmux_pa_ws="\${1#--workspace=}"; shift ;;
      --wait) hmux_pa_wait=1; shift ;;
      --output) hmux_pa_output=1; hmux_pa_wait=1; shift ;;
      --timeout) [ "\$#" -ge 2 ] || die "vm agent: --timeout needs seconds" 2; hmux_pa_timeout="\$2"; hmux_pa_wait=1; shift 2 ;;
      --timeout=*) hmux_pa_timeout="\${1#--timeout=}"; hmux_pa_wait=1; shift ;;
      --json) hmux_pa_json=1; shift ;;
      --) shift; break ;;
      claude|codex|opencode|pi) if [ -z "\$hmux_pa_agent" ]; then hmux_pa_agent="\$1"; shift; else break; fi ;;
      *) break ;;
    esac
  done
  [ -n "\$hmux_pa_agent" ] || die "usage: hmux vm agent <machine> --agent <claude|codex|opencode|pi> [--name <n>] [--cwd <dir>] [--workspace <ws>] [--wait [--output] [--timeout <s>]] -- <prompt or args…>" 2
  case "\$hmux_pa_agent" in
    claude|codex|opencode|pi) ;;
    *) die "vm agent: unsupported agent '\$hmux_pa_agent' (choose claude, codex, opencode, or pi)" 2 ;;
  esac
  [ -z "\$hmux_pa_timeout" ] || timeout_ms "\$hmux_pa_timeout" "vm agent" >/dev/null
  use_peer "\$hmux_pa_peer"
  [ -n "\$hmux_pa_ws" ] || hmux_pa_ws="\$(target_workspace)"
  [ -n "\$hmux_pa_name" ] || hmux_pa_name="\$hmux_pa_agent"
  if [ -n "\$hmux_pa_cwd" ]; then
    set -- workspace "\$hmux_pa_ws" run --on-exit keep --name "\$hmux_pa_name" --cwd "\$hmux_pa_cwd" -- hmux agent "\$hmux_pa_agent" "\$@"
  else
    set -- workspace "\$hmux_pa_ws" run --on-exit keep --name "\$hmux_pa_name" -- hmux agent "\$hmux_pa_agent" "\$@"
  fi
  if hmux_out="\$(tui --json "\$@" 2>&1)"; then :; else die "vm agent: could not start \$hmux_pa_agent on \$hmux_pa_peer: \$hmux_out" 1; fi
  hmux_pa_term="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .terminal_id // empty')"
  hmux_pa_wsid="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .workspace_id // empty')"
  if [ "\$hmux_pa_wait" -eq 1 ]; then
    [ -n "\$hmux_pa_term" ] || die "vm agent: \$hmux_pa_peer returned no terminal id, so there is nothing to wait for: \$hmux_out" 1
    if [ "\$hmux_pa_json" -eq 0 ]; then
      printf 'started terminal=%s workspace=%s machine=%s agent=%s; waiting%s\\n' "\$hmux_pa_term" "\${hmux_pa_wsid:-\$hmux_pa_ws}" "\$hmux_pa_peer" "\$hmux_pa_agent" "\${hmux_pa_timeout:+ up to \${hmux_pa_timeout}s}" >&2
    fi
    agent_wait_terminal "\$hmux_pa_term" "\$hmux_pa_timeout" "\$hmux_pa_output" "\$hmux_pa_json" "\$hmux_pa_peer" "\$hmux_pa_agent" "\${hmux_pa_wsid:-\$hmux_pa_ws}" || exit "\$?"
    return 0
  fi
  if [ "\$hmux_pa_json" -eq 1 ]; then
    jq -n --arg term "\${hmux_pa_term:-}" --arg ws "\${hmux_pa_wsid:-\$hmux_pa_ws}" --arg machine "\$hmux_pa_peer" --arg agent "\$hmux_pa_agent" \\
      '{terminal_id: \$term, workspace_id: \$ws, machine: \$machine, agent: \$agent, state: "running"}'
    return 0
  fi
  printf 'OK terminal=%s workspace=%s machine=%s agent=%s (detached: it keeps running on the peer; read it with hmux vm terminal read %s %s)\\n' \\
    "\${hmux_pa_term:-?}" "\${hmux_pa_wsid:-\$hmux_pa_ws}" "\$hmux_pa_peer" "\$hmux_pa_agent" "\$hmux_pa_peer" "\${hmux_pa_term:-<term>}"
}

# peer_deliver <label> <MARKER> <terminal-name> <scratch-dir> <payload-file> -- <receiver argv…>:
# the sending half of a receive handshake on the current peer target. Starts the
# receiver in a durable terminal (--on-exit keep: its final OK/ERR line must stay
# readable), waits for HMUX-<MARKER>-READY (echo is off by then), types the
# payload as 76-column base64 lines plus HMUX-<MARKER>-END in 1 KiB writes, reads
# one HMUX-<MARKER>-(OK|ERR) line and closes the terminal. Sets hmux_pd_line to
# that line ("" when the receiver never answered). Payload bytes travel only
# inside the typed stream: never in a run argv (visible in process lists) and
# never through a control plane. Transport failures remove <scratch-dir> and die.
peer_deliver() {
  hmux_pd_label="\$1"
  hmux_pd_marker="\$2"
  hmux_pd_name="\$3"
  hmux_pd_dir="\$4"
  hmux_pd_payload="\$5"
  shift 5
  [ "\${1:-}" = "--" ] && shift
  hmux_pd_verb="\$(printf '%s' "\$hmux_pd_marker" | tr 'A-Z' 'a-z')"
  hmux_pd_ws="\$(target_workspace)"
  if hmux_out="\$(tui --json workspace "\$hmux_pd_ws" run --on-exit keep --name "\$hmux_pd_name" -- "\$@" 2>&1)"; then :; else
    rm -rf "\$hmux_pd_dir"; die "\$hmux_pd_label: could not start the receiver on \$TARGET_LABEL: \$hmux_out" 1
  fi
  hmux_pd_term="\$(printf '%s\\n' "\$hmux_out" | jq -r '(.value // .) | .terminal_id // empty')"
  [ -n "\$hmux_pd_term" ] || { rm -rf "\$hmux_pd_dir"; die "\$hmux_pd_label: the receiver on \$TARGET_LABEL returned no terminal id: \$hmux_out" 1; }
  hmux_pd_ready="\$(tui --json terminal "\$hmux_pd_term" screen wait --pattern "HMUX-\$hmux_pd_marker-READY" --timeout-ms 15000 2>/dev/null || true)"
  if [ "\$(printf '%s\\n' "\$hmux_pd_ready" | jq -r '(.value // .) | if .matched == true then 1 else 0 end' 2>/dev/null || printf 0)" != 1 ]; then
    hmux_pd_seen="\$(printf '%s\\n' "\$hmux_pd_ready" | jq -r '(.value // .) | .text // ""' 2>/dev/null | grep -Eo "HMUX-\$hmux_pd_marker-ERR[^[:cntrl:]]*" | tail -n 1 || true)"
    tui --json terminal "\$hmux_pd_term" close >/dev/null 2>&1 || true
    rm -rf "\$hmux_pd_dir"
    [ -z "\$hmux_pd_seen" ] || die "\$hmux_pd_label on \$TARGET_LABEL failed: \${hmux_pd_seen#HMUX-\$hmux_pd_marker-ERR }" 1
    die "\$hmux_pd_label: the receiver on \$TARGET_LABEL never became ready (its hmux shim may predate \$hmux_pd_verb receive; reconnect the machine to heal it)" 1
  fi
  { base64 < "\$hmux_pd_payload" | tr -d '\\n' | fold -w 76; printf '\\nHMUX-%s-END\\n' "\$hmux_pd_marker"; } > "\$hmux_pd_dir/stream"
  split -b 1024 "\$hmux_pd_dir/stream" "\$hmux_pd_dir/piece."
  for hmux_pd_piece in "\$hmux_pd_dir"/piece.*; do
    [ -f "\$hmux_pd_piece" ] || continue
    hmux_pd_b64="\$(base64 < "\$hmux_pd_piece" | tr -d '\\n')"
    if ! tui --json terminal "\$hmux_pd_term" write --bytes-base64 "\$hmux_pd_b64" >/dev/null 2>&1; then
      tui --json terminal "\$hmux_pd_term" close >/dev/null 2>&1 || true
      rm -rf "\$hmux_pd_dir"
      die "\$hmux_pd_label: the link to \$TARGET_LABEL dropped while sending" 1
    fi
  done
  hmux_pd_result="\$(tui --json terminal "\$hmux_pd_term" screen wait --pattern "HMUX-\$hmux_pd_marker-(OK|ERR)" --timeout-ms 30000 2>/dev/null || true)"
  hmux_pd_line="\$(printf '%s\\n' "\$hmux_pd_result" | jq -r '(.value // .) | .text // ""' 2>/dev/null | grep -Eo "HMUX-\$hmux_pd_marker-(OK|ERR)[^[:cntrl:]]*" | tail -n 1 || true)"
  tui --json terminal "\$hmux_pd_term" close >/dev/null 2>&1 || true
}

# \`hmux vm env set <peer> …\`: values onto a peer through its \`hmux env receive\`.
peer_env_set() {
  hmux_pe_peer="\$1"
  shift
  hmux_pe_dir="\$(mktemp -d "\${TMPDIR:-/tmp}/hmux-env-send.XXXXXX")"
  env_collect_input "\$hmux_pe_dir/payload" "\$@"
  hmux_pe_n="\$(grep -c . "\$hmux_pe_dir/payload" || true)"
  hmux_pe_names="\$(sed 's/=.*//' "\$hmux_pe_dir/payload" | tr '\\n' ' ')"
  use_peer "\$hmux_pe_peer"
  peer_deliver "vm env set" ENV "hmux env" "\$hmux_pe_dir" "\$hmux_pe_dir/payload" -- hmux env receive
  rm -rf "\$hmux_pe_dir"
  case "\$hmux_pd_line" in
    HMUX-ENV-OK*)
      printf 'OK set %s variable%s on %s: %s(new hmux shells and agents there see them)\\n' "\$hmux_pe_n" "\$([ "\$hmux_pe_n" = 1 ] || printf s)" "\$hmux_pe_peer" "\$hmux_pe_names"
      ;;
    HMUX-ENV-ERR*)
      die "vm env set on \$hmux_pe_peer failed: \${hmux_pd_line#HMUX-ENV-ERR }" 1
      ;;
    *)
      die "vm env set: no answer from the receiver on \$hmux_pe_peer within 30s" 1
      ;;
  esac
}

# \`hmux vm push <peer> <local-file> <remote-path> [--mode <octal>] [--json]\`:
# one file onto a linked machine through its \`hmux file receive\`, the handshake
# the Mac's \`hmux vm push --secret\` uses. Single files up to 256 KiB, always
# over the link: secret-safe by construction, so there is no --secret flag here.
peer_push() {
  hmux_pp_peer="\$1"
  shift
  hmux_pp_local=""
  hmux_pp_remote=""
  hmux_pp_mode=600
  hmux_pp_json=0
  hmux_pp_usage="usage: hmux vm push <machine> <local-file> <remote-path> [--mode <octal>] [--json]"
  while [ "\$#" -gt 0 ]; do
    case "\$1" in
      --mode) [ "\$#" -ge 2 ] || die "vm push: --mode needs an octal mode such as 600 or 755" 2; hmux_pp_mode="\$2"; shift 2 ;;
      --mode=*) hmux_pp_mode="\${1#--mode=}"; shift ;;
      --json) hmux_pp_json=1; shift ;;
      --help|-h) peer_usage; return 0 ;;
      --secret) shift ;;
      -*) die "vm push: unknown option \$1 (\$hmux_pp_usage)" 2 ;;
      *)
        if [ -z "\$hmux_pp_local" ]; then hmux_pp_local="\$1"
        elif [ -z "\$hmux_pp_remote" ]; then hmux_pp_remote="\$1"
        else die "vm push: one local file and one remote path (\$hmux_pp_usage)" 2; fi
        shift ;;
    esac
  done
  [ -n "\$hmux_pp_local" ] && [ -n "\$hmux_pp_remote" ] || die "\$hmux_pp_usage" 2
  file_mode_ok "\$hmux_pp_mode" || die "vm push: --mode takes an octal mode such as 600 or 755, got '\$hmux_pp_mode'" 2
  [ ! -d "\$hmux_pp_local" ] || die "vm push: \$hmux_pp_local is a directory; from inside a machine push one file at a time (tar it first)" 2
  [ -f "\$hmux_pp_local" ] && [ -r "\$hmux_pp_local" ] || die "vm push: cannot read \$hmux_pp_local" 2
  hmux_pp_bytes="\$(wc -c < "\$hmux_pp_local" | tr -d ' ')"
  [ "\$hmux_pp_bytes" -gt 0 ] || die "vm push: \$hmux_pp_local is empty" 2
  [ "\$hmux_pp_bytes" -le 262144 ] || die "vm push: \$hmux_pp_local is \$hmux_pp_bytes bytes; the link carries files up to 262144 bytes (256 KiB)" 2
  hmux_pp_dir="\$(mktemp -d "\${TMPDIR:-/tmp}/hmux-file-send.XXXXXX")"
  use_peer "\$hmux_pp_peer"
  peer_deliver "vm push" FILE "hmux file" "\$hmux_pp_dir" "\$hmux_pp_local" -- hmux file receive "\$hmux_pp_remote" --mode "\$hmux_pp_mode"
  rm -rf "\$hmux_pp_dir"
  case "\$hmux_pd_line" in
    HMUX-FILE-OK*)
      hmux_pp_rest="\${hmux_pd_line#HMUX-FILE-OK }"
      hmux_pp_landed="\${hmux_pp_rest#*path=}"
      hmux_pp_landed="\${hmux_pp_landed% mode=*}"
      [ -n "\$hmux_pp_landed" ] || hmux_pp_landed="\$hmux_pp_remote"
      if [ "\$hmux_pp_json" -eq 1 ]; then
        jq -n --arg machine "\$hmux_pp_peer" --arg path "\$hmux_pp_landed" --arg mode "\$hmux_pp_mode" --argjson bytes "\$hmux_pp_bytes" \\
          '{machine: \$machine, path: \$path, bytes: \$bytes, mode: \$mode, transport: "link"}'
      else
        printf 'OK %s on %s (%s bytes, mode %s) delivered over the link\\n' "\$hmux_pp_landed" "\$hmux_pp_peer" "\$hmux_pp_bytes" "\$hmux_pp_mode"
      fi
      ;;
    HMUX-FILE-ERR*)
      die "vm push to \$hmux_pp_peer failed: \${hmux_pd_line#HMUX-FILE-ERR }" 1
      ;;
    *)
      die "vm push: no answer from the receiver on \$hmux_pp_peer within 30s" 1
      ;;
  esac
}

# \`hmux vm workspace new|rename|close|rm <peer> …\` in the Mac's spelling.
# Name-based creation is fenced by the authoritative daemon revision. Only a
# revision conflict retries; a failed mutation is never blindly repeated.
guest_workspace_get_or_create() {
  hmux_gc_name="\$1"; hmux_gc_empty="\$2"; hmux_gc_attempt=0
  [ -n "\$hmux_gc_name" ] || die_message 2 workspaceReuseNeedsName
  while [ "\$hmux_gc_attempt" -lt 8 ]; do
    hmux_gc_attempt=\$((hmux_gc_attempt + 1))
    hmux_gc_snapshot="\$(layout_snapshot)"
    hmux_gc_plan="\$(printf '%s\\n' "\$hmux_gc_snapshot" | jq -ce --arg name "\$hmux_gc_name" '
      (.value // .) | select((.workspaces | type) == "array")
      | {matches: [.workspaces[] | select(.name == \$name)], revision: (.cursor.revision // .session.revision)}
      | select((.revision | type) == "string" and (.revision | test("^[0-9]+\$")))
    ')" || die_message 1 workspaceReuseUnavailable
    hmux_gc_count="\$(printf '%s\\n' "\$hmux_gc_plan" | jq -r '.matches | length')"
    [ "\$hmux_gc_count" -le 1 ] || die_message 2 workspaceReuseAmbiguous
    if [ "\$hmux_gc_count" = 1 ]; then
      printf '%s\\n' "\$hmux_gc_plan" | jq -ce '{value: .matches[0], existing: true}'
      return
    fi
    hmux_gc_revision="\$(printf '%s\\n' "\$hmux_gc_plan" | jq -r .revision)"
    set -- --json --expected-revision "\$hmux_gc_revision" workspace create --name "\$hmux_gc_name"
    [ "\$hmux_gc_empty" != 1 ] || set -- "\$@" --empty
    if hmux_gc_out="\$(tui "\$@" 2>&1)"; then
      printf '%s\\n' "\$hmux_gc_out" | jq -ce 'select(type == "object") | . + {existing: false}'
      return
    fi
    hmux_gc_code="\$(printf '%s\\n' "\$hmux_gc_out" | jq -r '.code // .error.code // empty' 2>/dev/null)" || hmux_gc_code=""
    [ "\$hmux_gc_code" = revision.conflict ] || die "\$hmux_gc_out" 1
  done
  die_message 1 workspaceReuseUnavailable
}

workspace_verb() {
  hmux_pw_verb="\$1"
  hmux_pw_peer="\$TARGET_LABEL"
  shift
  case "\$hmux_pw_verb" in
    new)
      hmux_pw_json=""
      hmux_pw_name=""
      hmux_pw_reuse=0
      while [ "\$#" -gt 0 ]; do
        case "\$1" in
          --name) [ "\$#" -ge 2 ] || die "vm workspace new: --name needs a value" 2; hmux_pw_name="\$2"; shift 2 ;;
          --name=*) hmux_pw_name="\${1#--name=}"; shift ;;
          --json) hmux_pw_json=--json; shift ;;
          --no-open) shift ;;
          --reuse) hmux_pw_reuse=1; shift ;;
          *) die "vm workspace new: unknown option \$1" 2 ;;
        esac
      done
      if [ "\$hmux_pw_reuse" = 1 ]; then
        hmux_pw_result="\$(guest_workspace_get_or_create "\$hmux_pw_name" 0)" || return \$?
        if [ -n "\$hmux_pw_json" ]; then printf '%s\\n' "\$hmux_pw_result"; else
          printf '%s\\n' "\$hmux_pw_result" | jq -r '(.value // .) | .id // .workspace_id'
        fi
        return
      fi
      if [ -n "\$hmux_pw_name" ]; then exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" \$hmux_pw_json workspace create --name "\$hmux_pw_name"; fi
      exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" \$hmux_pw_json workspace create
      ;;
    rm|delete)
      [ "\$#" -ge 1 ] || die "usage: hmux vm workspace rm <machine> <ws>" 2
      hmux_pw_ws="\$1"
      hmux_pw_snap="\$(layout_snapshot)"
      hmux_pw_terms="\$(printf '%s\\n' "\$hmux_pw_snap" | jq -r --arg ws "\$hmux_pw_ws" '
        [ (.screens // [])[] | select(.workspace_id == \$ws) | .id ] as \$screens
        | [ (.panes // [])[] | select(.screen_id as \$sid | \$screens | index(\$sid)) | .id ] as \$panes
        | [ (.tabs // [])[] | select(.content_kind == "terminal" and (.pane_id as \$pid | \$panes | index(\$pid))) | .content_id ] | unique | .[]')"
      hmux_pw_killed=0
      for hmux_pw_term in \$hmux_pw_terms; do
        tui terminal "\$hmux_pw_term" close >/dev/null 2>&1 || warn "could not close terminal \$hmux_pw_term"
        hmux_pw_killed=\$((hmux_pw_killed + 1))
      done
      tui workspace "\$hmux_pw_ws" close >/dev/null
      printf 'OK deleted workspace %s on %s (%s terminal%s closed)\\n' "\$hmux_pw_ws" "\$hmux_pw_peer" "\$hmux_pw_killed" "\$([ "\$hmux_pw_killed" = 1 ] || printf s)"
      ;;
  esac
}

case "\${1:-}" in
  --version|-v|version)
    hmux_message version
    exec "\$HMUX_TUI_BIN" --version
    ;;
  --help|help|"")
    guest_usage
    ;;
  auth)
    shift
    auth_sub="\${1:-status}"
    [ "\$#" -gt 0 ] && shift
    case "\$auth_sub" in
      status) guest_auth_status "\$@" ;;
      login|logout) host_only_command "hmux auth \$auth_sub" ;;
      help|--help|-h) guest_usage ;;
      *) die_message 2 unknownAuth "\$auth_sub" ;;
    esac
    ;;
  login|logout)
    host_only_command "hmux \$1"
    ;;
  coderouter|cr)
    shift
    guest_coderouter_command "\$@"
    ;;
  agent)
    shift
    guest_agent_command "\$@"
    ;;
  ai-accounts|remotes)
    host_only_command "hmux \$1"
    ;;
  self|whoami|reflect|reflection)
    shift
    guest_self "\$@"
    ;;
  env)
    shift
    guest_env_command "\$@"
    ;;
  file)
    shift
    guest_file_command "\$@"
    ;;
  layout)
    shift
    guest_layout_command "\$@"
    ;;
  tree)
    shift
    for hmux_arg in "\$@"; do
      case "\$hmux_arg" in
        --json) ;;
        *) die "usage: hmux tree [--json]  (this machine's workspace/terminal snapshot; hmux vm tree <machine> for a peer)" 2 ;;
      esac
    done
    exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" --json session current snapshot
    ;;
  new-workspace)
    shift
    workspace_verb new "\$@"
    ;;
  new-split)
    shift
    hmux_ns_dir="\${1:-}"
    case "\$hmux_ns_dir" in
      right|down) shift ;;
      left|up) die "new-split: the daemon splits to the right or down only (the new pane lands right of / below the pane); use right or down" 2 ;;
      *) die "usage: hmux new-split <right|down> [--pane <pane_id>]" 2 ;;
    esac
    hmux_ns_pane=""
    while [ "\$#" -gt 0 ]; do
      case "\$1" in
        --pane) [ "\$#" -ge 2 ] || die "new-split: --pane needs a pane id" 2; hmux_ns_pane="\$2"; shift 2 ;;
        --pane=*) hmux_ns_pane="\${1#--pane=}"; shift ;;
        --json) shift ;;
        *) die "usage: hmux new-split <right|down> [--pane <pane_id>]" 2 ;;
      esac
    done
    [ -n "\$hmux_ns_pane" ] || hmux_ns_pane="\$(default_pane)"
    exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" pane "\$hmux_ns_pane" split "--\$hmux_ns_dir"
    ;;
  send|send-key|read-screen)
    local_terminal_alias "\$@"
    ;;
  workspace|pane|tab)
    hmux_noun="\$1"; shift
    guest_topology_command "\$hmux_noun" "\$@"
    ;;
  terminal)
    # The Mac's verb-first spelling (\`terminal send <id> …\`); hmux-tui's own
    # id-first grammar (\`terminal <id> write …\`, \`terminal list\`) passes through.
    case "\${2:-}" in
      help|--help|-h)
        terminal_usage
        ;;
      send|write|read|screen|wait|wait-exit|output|close|rename|move)
        hmux_verb="\$2"
        hmux_term="\${3:-}"
        shift 2
        [ "\$#" -gt 0 ] && shift
        terminal_verb "\$hmux_verb" "\$hmux_term" "\$@"
        ;;
      *)
        exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" "\$@"
        ;;
    esac
    ;;
  vm)
    shift
    sub="\${1:-}"; [ "\$#" -gt 0 ] && shift
    case "\$sub" in
      ls|list|peers|links)
        guest_vm_ls "\$@"
        ;;
      connect)
        peer="\${1:-}"; [ -n "\$peer" ] || die_message 2 connectUsage
        sock="\$(ensure_link "\$peer")"
        hmux_message connected "\$peer" "\$sock"
        ;;
      exec)
        peer="\${1:-}"; [ -n "\$peer" ] || die_message 2 execUsage
        shift
        [ "\${1:-}" = "--" ] && shift
        [ "\$#" -gt 0 ] || die_message 2 execUsage
        use_peer "\$peer"
        sock="\$TARGET_VALUE"
        # A fresh session has no current workspace; create one and run in it by id.
        target="\$(target_workspace)"
        exec "\$HMUX_TUI_BIN" --socket "\$sock" workspace "\$target" run --on-exit close -- "\$@"
        ;;
      push)
        # The Mac spelling puts --secret first; here every push is link-typed, so it is accepted and means nothing extra.
        [ "\${1:-}" != --secret ] || shift
        peer="\${1:-}"; [ -n "\$peer" ] || die "usage: hmux vm push <machine> <local-file> <remote-path> [--mode <octal>]" 2
        shift
        peer_push "\$peer" "\$@"
        ;;
      terminal)
        case "\${1:-}" in
          help|--help|-h) terminal_usage ;;
          send|write|read|screen|wait|wait-exit|output|close|rename|move)
            hmux_verb="\$1"
            peer="\${2:-}"
            hmux_term="\${3:-}"
            [ -n "\$peer" ] || die "usage: hmux vm terminal \$hmux_verb <machine> <term> …" 2
            shift 2
            [ "\$#" -gt 0 ] && shift
            use_peer "\$peer"
            terminal_verb "\$hmux_verb" "\$hmux_term" "\$@"
            ;;
          *)
            peer="\${1:-}"; [ -n "\$peer" ] || die "usage: hmux vm terminal <machine> [args…]" 2
            shift
            use_peer "\$peer"
            exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" terminal "\$@"
            ;;
        esac
        ;;
      send|send-key|read-screen)
        peer="\${1:-}"
        hmux_term="\${2:-}"
        [ -n "\$peer" ] && [ -n "\$hmux_term" ] || die "usage: hmux vm \$sub <machine> <term> …" 2
        shift 2
        use_peer "\$peer"
        case "\$sub" in
          send) [ "\$#" -gt 0 ] || die "usage: hmux vm send <machine> <term> <text>" 2; exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" terminal "\$hmux_term" write --text "\$*" ;;
          send-key) [ "\$#" -gt 0 ] || die "usage: hmux vm send-key <machine> <term> <key> [key…]" 2; exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" terminal "\$hmux_term" keys "\$@" ;;
          read-screen)
            hmux_rs_json=""
            for hmux_arg in "\$@"; do case "\$hmux_arg" in --json) hmux_rs_json=--json ;; *) die "usage: hmux vm read-screen <machine> <term> [--json]" 2 ;; esac; done
            # shellcheck disable=SC2086
            exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" \$hmux_rs_json terminal "\$hmux_term" screen read
            ;;
        esac
        ;;
      workspace)
        case "\${1:-}" in
          help|--help|-h|"") hmux_message topologyHelp ;;
          new|rename|close|rm|delete|move|focus|list|ls|show)
            hmux_verb="\$1"; peer="\${2:-}"
            [ -n "\$peer" ] || die_message 2 topologyUsage
            shift 2
            use_peer "\$peer"
            guest_topology_command workspace "\$hmux_verb" "\$@"
            ;;
          *)
            peer="\${1:-}"; [ -n "\$peer" ] || die "usage: hmux vm workspace <machine> [args…]" 2
            shift
            use_peer "\$peer"
            exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" workspace "\$@"
            ;;
        esac
        ;;
      agent)
        peer="\${1:-}"; [ -n "\$peer" ] || die "usage: hmux vm agent <machine> --agent <claude|codex|opencode|pi> -- <prompt or args…>" 2
        case "\${2:-}" in
          --agent|--agent=*|claude|codex|opencode|pi|--wait|--output|--timeout|--timeout=*|--name|--name=*|--cwd|--cwd=*|--workspace|--workspace=*) peer_agent "\$@" ;;
          *)
            shift
            use_peer "\$peer"
            exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" agent "\$@"
            ;;
        esac
        ;;
      layout)
        hmux_layout_sub="\${1:-}"
        peer="\${2:-}"
        case "\$hmux_layout_sub" in
          export|get|apply|open) ;;
          *) die "usage: hmux vm layout export|apply <machine> [options]  (see hmux layout help)" 2 ;;
        esac
        [ -n "\$peer" ] || die "usage: hmux vm layout \$hmux_layout_sub <machine> [options]" 2
        shift 2
        use_peer "\$peer"
        guest_layout_command "\$hmux_layout_sub" "\$@"
        ;;
      env)
        hmux_env_sub="\${1:-}"
        peer="\${2:-}"
        case "\$hmux_env_sub" in
          set|ls|list|rm|unset|remove|path) ;;
          *) die "usage: hmux vm env set|ls|rm|path <machine> …  (see hmux env help)" 2 ;;
        esac
        [ -n "\$peer" ] || die "usage: hmux vm env \$hmux_env_sub <machine> …" 2
        shift 2
        if [ "\$hmux_env_sub" = set ]; then
          peer_env_set "\$peer" "\$@"
        else
          # Names only ever ride argv here; values go through peer_env_set.
          use_peer "\$peer"
          target="\$(target_workspace)"
          exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" workspace "\$target" run --on-exit close -- hmux env "\$hmux_env_sub" "\$@"
        fi
        ;;
      pane|tab)
        case "\${1:-}" in
          help|--help|-h|"") hmux_message topologyHelp ;;
          list|ls|show|rename|focus|close|move|split|swap|zoom|resize)
            hmux_verb="\$1"; peer="\${2:-}"
            [ -n "\$peer" ] || die_message 2 topologyUsage
            shift 2
            use_peer "\$peer"
            guest_topology_command "\$sub" "\$hmux_verb" "\$@"
            ;;
          *)
            peer="\$1"; shift
            use_peer "\$peer"
            guest_topology_command "\$sub" "\$@"
            ;;
        esac
        ;;
      tui|tree|session|screen|browser)
        # hmux vm <verb> <machine> [args…] → the same hmux-tui verb on the peer.
        peer="\${1:-}"; [ -n "\$peer" ] || die_message 2 peerUsage "\$sub"
        shift
        use_peer "\$peer"
        if [ "\$sub" = tui ]; then exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE"; fi
        if [ "\$sub" = tree ]; then exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" --json session current snapshot; fi
        exec "\$HMUX_TUI_BIN" "\$TARGET_FLAG" "\$TARGET_VALUE" "\$sub" "\$@"
        ;;
      ""|help|--help|-h)
        peer_usage
        ;;
      *) die_message 2 unknownVM "\$sub" ;;
    esac
    ;;
  notify)
    # Mac-CLI compatible \`hmux notify\` inside a machine (agent hooks call it
    # with --title/--subtitle/--body). hmux-tui's own \`notify\` verb takes the
    # macOS signature: it stores --subtitle as its own field, scopes --clear,
    # refuses --reply, and validates any selector it is handed, so the shim
    # forwards the arguments verbatim and the daemon stays the one place that
    # knows the grammar. Nothing here can name a Mac workspace, surface, or
    # socket: those selectors are rejected by the daemon rather than mapped.
    shift
    # Silent on success like the Mac CLI, unless the caller asked for the
    # JSON result: --quiet and --json are exclusive global output modes.
    hmux_notify_json=
    for hmux_notify_arg in "\$@"; do
      case "\$hmux_notify_arg" in
        --json|--jsonl) hmux_notify_json=1; break ;;
      esac
    done
    if [ -n "\$hmux_notify_json" ]; then
      exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" notify "\$@"
    fi
    exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" --quiet notify "\$@"
    ;;
  *)
    # Local daemon session. hmux-tui's own grammar is \`hmux <resource> <action>\`.
    local_alias "\$@" 2>/dev/null || exec "\$HMUX_TUI_BIN" --session "\$LOCAL_SESSION" "\$@"
    ;;
esac
`;

/** Shell command installing the shim (idempotent; safe to run on every heal). */
export function guestCliInstallCommand(): string {
  const encoded = Buffer.from(GUEST_HMUX_SHIM, "utf8").toString("base64");
  return [
    `mkdir -p /usr/local/libexec`,
    `printf '%s' '${encoded}' | base64 -d > ${GUEST_HMUX_SHIM_PATH}.tmp`,
    guestBrowserInstallCommand(),
    `chmod 0755 ${GUEST_HMUX_SHIM_PATH}.tmp`,
    `mv ${GUEST_HMUX_SHIM_PATH}.tmp ${GUEST_HMUX_SHIM_PATH}`,
    guestCliDistributionCommand(),
  ].join(" && ");
}
