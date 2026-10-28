# hmux shell integration for zsh
# Injected automatically — do not source manually

# Socket sends exec a unix-socket-capable client in a detached child. The
# historical zsocket fast path (zmodload zsh/net/unix) never activated because
# that module does not exist (zsocket lives in zsh/net/socket). Enabling it
# would also lose response-based ordering between connections and introduce an
# unbounded blocked child. A future fast path still needs one connection per
# batch plus bounded response reads.

typeset -g _HMUX_HAS_ZSH_JOBSTATES=0
if zmodload zsh/parameter 2>/dev/null && (( ${+jobstates} )); then
    _HMUX_HAS_ZSH_JOBSTATES=1
fi

# Prefer zsh/zselect for the poll-loop sleeps in the git-HEAD and PR-status
# watchers (no fork, vs ~1 fork+exec of /bin/sleep per second per pane).
# Falls back to /bin/sleep if the module is unavailable.
typeset -g _HMUX_HAS_ZSELECT=0
if zmodload zsh/zselect 2>/dev/null; then
    _HMUX_HAS_ZSELECT=1
fi

# Fork-free sleep.  Argument is in centiseconds (zselect's -t unit), so a
# whole-second wait is `_hmux_sleep_cs 100`.  zselect with only -t and no fds
# returns status 1 on timeout, so call it then return 0 explicitly rather than
# falling through to the /bin/sleep fallback (which would double the wait).
_hmux_sleep_cs() {
    if (( _HMUX_HAS_ZSELECT )); then
        # Timeout is zselect's normal status 1. Consume it before returning so
        # callers with ERR_RETURN/ERR_EXIT enabled do not abort the watcher.
        zselect -t "$1" || :
        return 0
    fi
    sleep "$(( $1 / 100.0 ))"
}

_hmux_zsh_job_table_saturated() {
    (( _HMUX_HAS_ZSH_JOBSTATES )) || return 1

    local limit="${HMUX_ZSH_JOB_TABLE_SOFT_LIMIT:-900}"
    case "$limit" in
        ''|*[!0-9]*) limit=900 ;;
    esac
    (( limit > 0 )) || limit=900

    local job_count=${#jobstates}
    (( job_count >= limit ))
}

_hmux_restore_status() {
    builtin return "$1"
}

# BSD nc at /usr/bin/nc is preferred: it always supports -U, it waits for the
# server to process the line and close (which preserves send order across a
# batched child), and -w bounds its lifetime. PATH `nc` cannot be trusted first:
# GNU netcat (e.g. Homebrew in /usr/local/bin) lacks -U and fails silently,
# which dropped every hook message (report_tty, ports_kick, report_shell_state)
# on machines where it shadows the system nc. The capability envelope keeps
# the detached client authorized even after launchd or tmux reparents it.
_hmux_write_socket_payload() {
    local payload="$1"
    case "${HMUX_SOCKET_CAPABILITY:-}" in
        ""|*[[:space:]]*)
            print -r -- "$payload"
            ;;
        *)
            print -r -- "_hmux_capability_v1 $HMUX_SOCKET_CAPABILITY $payload"
            ;;
    esac
}

_hmux_send() {
    local payload="$1"
    if [[ -x /usr/bin/nc ]]; then
        # Apple's nc defines -N as `num_probes` (it is not OpenBSD's no-arg
        # shutdown-after-EOF flag), so the -N form fails option parsing; use
        # the bounded -w form directly. nc waits for the server to process the
        # line and close, preserving order in a batched child.
        _hmux_write_socket_payload "$payload" | /usr/bin/nc -w 1 -U "$HMUX_SOCKET_PATH" >/dev/null 2>&1 || true
        return 0
    fi
    if command -v ncat >/dev/null 2>&1; then
        _hmux_write_socket_payload "$payload" | ncat -w 1 -U "$HMUX_SOCKET_PATH" --send-only
    elif command -v socat >/dev/null 2>&1; then
        _hmux_write_socket_payload "$payload" | socat -T 1 - "UNIX-CONNECT:$HMUX_SOCKET_PATH" >/dev/null 2>&1
    elif command -v nc >/dev/null 2>&1; then
        if _hmux_write_socket_payload "$payload" | nc -N -U "$HMUX_SOCKET_PATH" >/dev/null 2>&1; then
            :
        else
            _hmux_write_socket_payload "$payload" | nc -w 1 -U "$HMUX_SOCKET_PATH" >/dev/null 2>&1 || true
        fi
    fi
}

# Fire-and-forget send, always detached from the interactive shell: the
# client's connect and response wait must never run in the foreground, or a
# wedged hmux listener (hung app, full backlog, post-wake socket) blocks every
# precmd/preexec hook and freezes the user's prompt. Each child self-bounds
# via its client timeout (-w 1 / -T 1), so a wedged listener cannot
# accumulate children beyond roughly one second's worth of sends.
# Accepts multiple payloads: they are sent sequentially inside ONE child, so
# callers with an ordering dependency between two messages (report_tty before
# ports_kick) batch them instead of racing two independent children.
# Returns nonzero when the payload was dropped (job-table saturation) so
# callers with edge-triggered latches can leave them unset and retry.
_hmux_send_bg() {
    _hmux_zsh_job_table_saturated && return 1
    {
        local _hmux_msg
        for _hmux_msg in "$@"; do
            _hmux_send "$_hmux_msg"
        done
    } >/dev/null 2>&1 &!
    return 0
}

_hmux_socket_is_unix() {
    [[ -n "$HMUX_SOCKET_PATH" && -S "$HMUX_SOCKET_PATH" ]]
}

_hmux_relay_cli_path() {
    if [[ -n "${HMUX_BUNDLED_CLI_PATH:-}" && -x "${HMUX_BUNDLED_CLI_PATH}" ]]; then
        print -r -- "${HMUX_BUNDLED_CLI_PATH}"
        return 0
    fi
    command -v hmux 2>/dev/null
}

_hmux_socket_uses_remote_relay() {
    [[ -n "$HMUX_SOCKET_PATH" ]] || return 1
    [[ "$HMUX_SOCKET_PATH" == /* ]] && return 1
    [[ "$HMUX_SOCKET_PATH" == *:* ]] || return 1
    [[ -n "$(_hmux_relay_cli_path)" ]]
}

_hmux_has_port_scan_transport() {
    _hmux_socket_is_unix && return 0
    _hmux_socket_uses_remote_relay
}

_hmux_json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    print -r -- "$value"
}

_hmux_relay_rpc_bg() {
    local method="$1"
    local params="$2"
    local relay_cli=""
    _hmux_zsh_job_table_saturated && return 1
    _hmux_socket_uses_remote_relay || return 1
    relay_cli="$(_hmux_relay_cli_path)" || return 1
    { "$relay_cli" rpc "$method" "$params" >/dev/null 2>&1 || true } >/dev/null 2>&1 &!
}

_hmux_relay_rpc() {
    local method="$1"
    local params="$2"
    local relay_cli=""
    local response=""
    _hmux_socket_uses_remote_relay || return 1
    # Relay `hmux rpc` exits nonzero on server error. The real remote CLI prints
    # only the JSON result payload on success, while some test stubs return the
    # full `{"ok":...}` envelope. Retry only on explicit `ok:false`.
    relay_cli="$(_hmux_relay_cli_path)" || return 1
    response="$("$relay_cli" rpc "$method" "$params" 2>/dev/null)" || return 1
    response="${response//$'\n'/}"
    response="${response//$'\r'/}"
    [[ "$response" == *'"ok":false'* || "$response" == *'"ok": false'* ]] && return 1
    return 0
}

_hmux_relay_workspace_id() {
    if [[ -n "$HMUX_WORKSPACE_ID" ]]; then
        print -r -- "$HMUX_WORKSPACE_ID"
        return 0
    fi
    [[ -n "$HMUX_TAB_ID" ]] || return 1
    print -r -- "$HMUX_TAB_ID"
}

_hmux_report_tty_via_relay() {
    _hmux_socket_uses_remote_relay || return 1
    local workspace_id=""
    workspace_id="$(_hmux_relay_workspace_id)" || return 1
    [[ -n "$_HMUX_TTY_NAME" ]] || return 1
    [[ -n "$HMUX_TERMINAL_LIFECYCLE_ID" && -n "$HMUX_SSH_ATTEMPT_ID" ]] || return 1

    local tty_name_json params
    tty_name_json="$(_hmux_json_escape "$_HMUX_TTY_NAME")"
    params="{\"workspace_id\":\"$workspace_id\",\"tty_name\":\"$tty_name_json\",\"terminal_lifecycle_id\":\"$HMUX_TERMINAL_LIFECYCLE_ID\",\"attempt_id\":\"$HMUX_SSH_ATTEMPT_ID\""
    if [[ -n "$HMUX_PANEL_ID" ]]; then
        params+=",\"surface_id\":\"$HMUX_PANEL_ID\""
    fi
    params+="}"
    _hmux_relay_rpc "surface.report_tty" "$params"
}

_hmux_report_pwd_via_relay() {
    local pwd="$1"
    _hmux_socket_uses_remote_relay || return 1
    [[ -n "$pwd" ]] || return 1
    local workspace_id=""
    workspace_id="$(_hmux_relay_workspace_id)" || return 1

    local pwd_json params
    pwd_json="$(_hmux_json_escape "$pwd")"
    params="{\"workspace_id\":\"$workspace_id\",\"path\":\"$pwd_json\""
    if [[ -n "$HMUX_PANEL_ID" ]]; then
        params+=",\"surface_id\":\"$HMUX_PANEL_ID\""
    fi
    params+="}"
    _hmux_relay_rpc_bg "surface.report_pwd" "$params"
}

_hmux_report_git_branch_via_relay() {
    local branch="$1"
    _hmux_socket_uses_remote_relay || return 1
    [[ -n "$branch" ]] || return 1
    local workspace_id="" branch_json="" params=""
    workspace_id="$(_hmux_relay_workspace_id)" || return 1
    branch_json="$(_hmux_json_escape "$branch")"
    params="{\"workspace_id\":\"$workspace_id\",\"branch\":\"$branch_json\""
    if [[ -n "${HMUX_PANEL_ID:-}" ]]; then
        params+=",\"surface_id\":\"$HMUX_PANEL_ID\""
    fi
    params+="}"
    _hmux_relay_rpc "surface.report_git_branch" "$params"
}

_hmux_clear_git_branch_via_relay() {
    _hmux_socket_uses_remote_relay || return 1
    local workspace_id="" params=""
    workspace_id="$(_hmux_relay_workspace_id)" || return 1
    params="{\"workspace_id\":\"$workspace_id\""
    if [[ -n "${HMUX_PANEL_ID:-}" ]]; then
        params+=",\"surface_id\":\"$HMUX_PANEL_ID\""
    fi
    params+="}"
    _hmux_relay_rpc "surface.clear_git_branch" "$params"
}

_hmux_report_shell_activity_state_via_relay() {
    local state="$1"
    _hmux_socket_uses_remote_relay || return 1
    [[ -n "$state" ]] || return 1
    local workspace_id="" params=""
    workspace_id="$(_hmux_relay_workspace_id)" || return 1
    params="{\"workspace_id\":\"$workspace_id\",\"state\":\"$state\""
    if [[ -n "${HMUX_PANEL_ID:-}" ]]; then
        params+=",\"surface_id\":\"$HMUX_PANEL_ID\""
    fi
    if [[ -n "${HMUX_TERMINAL_LIFECYCLE_ID:-}" ]]; then
        params+=",\"terminal_lifecycle_id\":\"$HMUX_TERMINAL_LIFECYCLE_ID\""
    fi
    params+="}"
    _hmux_relay_rpc_bg "surface.report_shell_state" "$params"
}

_hmux_ports_kick_via_relay() {
    local reason="${1:-command}"
    _hmux_socket_uses_remote_relay || return 1
    local workspace_id=""
    workspace_id="$(_hmux_relay_workspace_id)" || return 1
    local params="{\"workspace_id\":\"$workspace_id\",\"reason\":\"$reason\""
    if [[ -n "$HMUX_PANEL_ID" ]]; then
        params+=",\"surface_id\":\"$HMUX_PANEL_ID\""
    fi
    params+="}"
    _hmux_relay_rpc_bg "surface.ports_kick" "$params"
}

_hmux_restore_scrollback_once() {
    local path="${HMUX_RESTORE_SCROLLBACK_FILE:-}"
    [[ -n "$path" ]] || return 0
    unset HMUX_RESTORE_SCROLLBACK_FILE
    local token="${path:t}"

    builtin printf '\033]1337;CurrentDir=kitty-shell-cwd://%s/.hmux/session-scrollback-replay/%s/start\007' "$HOST" "$token"

    if [[ -r "$path" ]]; then
        /bin/cat -- "$path" 2>/dev/null || true
        # The saved scrollback can end with the prompt that was active when
        # hmux quit. Clear that replayed line so the fresh startup prompt does
        # not accumulate another copy on every relaunch.
        builtin printf '\r\033[2K'
        /bin/rm -f -- "$path" >/dev/null 2>&1 || true
    fi

    # Valid kitty-shell-cwd URIs reach Ghostty's PWD action in PTY order. The
    # following real cwd report keeps the private boundary out of title state.
    builtin printf '\033]1337;CurrentDir=kitty-shell-cwd://%s/.hmux/session-scrollback-replay/%s/end\007' "$HOST" "$token"
    builtin printf '\033]1337;CurrentDir=kitty-shell-cwd://%s%s\007' "$HOST" "$PWD"
}
_hmux_restore_scrollback_once

# First-launch welcome banner. hmux passes the path of a one-shot token file in
# HMUX_SHOW_WELCOME_FILE instead of typing `hmux welcome` into the first
# workspace's shell, so the banner prints during startup and never lands in
# shell history. Only the shell whose `rm` of the token succeeds prints it, and
# never inside tmux, so children that inherited the variable cannot repeat it.
_hmux_show_welcome_once() {
    local token="${HMUX_SHOW_WELCOME_FILE:-${_HMUX_BOOTSTRAP_WELCOME_FILE:-}}"
    unset HMUX_SHOW_WELCOME_FILE _HMUX_BOOTSTRAP_WELCOME_FILE
    [[ -n "$token" ]] || return 0
    /bin/rm -- "$token" >/dev/null 2>&1 || return 0
    [[ -z "${TMUX:-}" ]] || return 0
    local cli="${HMUX_SHELL_INTEGRATION_DIR%/}"
    cli="${cli%/shell-integration}/bin/hmux"
    [[ -x "$cli" ]] || cli="$(_hmux_relay_cli_path)"
    [[ -n "$cli" ]] || return 0
    "$cli" welcome 2>/dev/null || true
}
_hmux_show_welcome_once

_hmux_now() {
    print -r -- "${EPOCHSECONDS:-$SECONDS}"
}

typeset -g _HMUX_CLAUDE_WRAPPER=""
typeset -g _HMUX_GROK_WRAPPER=""
typeset -g _HMUX_MUSE_WRAPPER=""
# Sets REPLY to PATH-style $2 with $1 moved to the front (and $3 dropped),
# without the subshell a command substitution would fork.
_hmux_path_prepend_unique_directory_into_reply() {
    local directory="$1"
    local current_path="${2-}"
    local skipped_directory="${3-}"
    local result="$directory"
    local rest="$current_path"
    local entry=""
    local has_more=false

    [[ -n "$directory" ]] || {
        REPLY="$current_path"
        return 0
    }
    [[ -n "$current_path" ]] || {
        REPLY="$directory"
        return 0
    }

    while true; do
        if [[ "$rest" == *:* ]]; then
            entry="${rest%%:*}"
            rest="${rest#*:}"
            has_more=true
        else
            entry="$rest"
            rest=""
            has_more=false
        fi

        if [[ "$entry" != "$directory" && ( -z "$skipped_directory" || "$entry" != "$skipped_directory" ) ]]; then
            result="$result:$entry"
        fi
        [[ "$has_more" == true ]] || break
    done

    REPLY="$result"
}

_hmux_path_prepend_unique_directory() {
    local REPLY
    _hmux_path_prepend_unique_directory_into_reply "$@"
    printf '%s' "$REPLY"
}
# Succeeds when every directory, checked in order, is an absolute path to a
# real directory (not a symlink) owned by this user that no one else can write
# to, with a safe ancestry. Sticky shared ancestors (such as /tmp) are safe;
# a non-sticky writable ancestor can rename a checked child after this check.
_hmux_private_dirs() {
    builtin emulate -L zsh
    local create="$1"
    shift
    local dir
    local -a private_dir
    (( $# )) || return 1
    for dir in "$@"; do
        [[ "$dir" == /* ]] || return 1
        if [[ "$create" == 1 && ! -e "$dir" && ! -L "$dir" ]]; then
            /bin/mkdir -m 700 -- "$dir" >/dev/null 2>&1 || return 1
        fi
        # Glob qualifiers use lstat: / rejects symlinks, U requires our euid
        # and f:go-w: requires no group or other write bit.
        private_dir=( "$dir"(N/Uf:go-w:) )
        (( ${#private_dir} )) || return 1
        _hmux_private_path_chain "$dir" || return 1
    done
}

_hmux_private_path_chain() {
    builtin emulate -L zsh
    local start="$1"
    local current="$start"
    local canonical=""
    while true; do
        _hmux_private_path_node "$current" || return 1
        [[ "$current" == "/" ]] && break
        current="${current%/*}"
        [[ -n "$current" ]] || current="/"
    done
    canonical="$(_hmux_resolve_path "$start")" || return 1
    [[ "$canonical" == "$start" ]] || _hmux_private_path_chain_resolved "$canonical"
}

_hmux_private_path_chain_resolved() {
    builtin emulate -L zsh
    local current="$1"
    while true; do
        _hmux_private_path_node "$current" || return 1
        [[ "$current" == "/" ]] && return 0
        current="${current%/*}"
        [[ -n "$current" ]] || current="/"
    done
}

_hmux_private_path_node() {
    builtin emulate -L zsh
    local current="$1"
    local owner=""
    if [[ -d "$current" && ! -L "$current" ]]; then
        owner="$(/usr/bin/find -P "$current" -prune \( -uid "$EUID" -o -uid 0 \) -print 2>/dev/null)"
        [[ "$owner" == "$current" ]] || return 1
        if [[ "$(/usr/bin/find -P "$current" -prune -type d ! -perm -020 ! -perm -002 -print 2>/dev/null)" == "$current" ]]; then
            return 0
        fi
        [[ "$(/usr/bin/find -P "$current" -prune -type d -perm -1000 -print 2>/dev/null)" == "$current" ]] || return 1
        return 0
    fi
    if [[ -L "$current" ]]; then
        owner="$(/usr/bin/find -P "$current" -prune \( -uid "$EUID" -o -uid 0 \) -print 2>/dev/null)"
        [[ "$owner" == "$current" ]]
        return $?
    fi
    return 1
}

_hmux_resolve_path() {
    if [[ -x /usr/bin/realpath ]]; then
        /usr/bin/realpath -- "$1"
    elif [[ -x /bin/realpath ]]; then
        /bin/realpath -- "$1"
    elif [[ -x /usr/bin/readlink ]]; then
        /usr/bin/readlink -f -- "$1"
    else
        return 1
    fi
}
typeset -g _HMUX_CLAUDE_WRAPPER_SHIM_VERIFIED=""
_hmux_install_cli_command_shim() {
    local command_name="$1"
    local wrapper_path="$2"
    local surface_component="${HMUX_SURFACE_ID:-$$}"
    local shim_root="${HMUX_CLAUDE_WRAPPER_SHIM_ROOT:-}"
    shim_root="${shim_root%/}"
    local shim_parent="${shim_root%/*}"
    local tmp_root="${TMPDIR:-/tmp}"
    local legacy_shim_root="${tmp_root%/}/hmux-cli-shims/$surface_component"
    local shim_state="${HOME:-}/.hmuxterm"
    local rejected_root=""
    local REPLY
    # An inherited root is reused only while it is still private. Otherwise
    # the shell makes its own, and skips the shim if it can't.
    if [[ -z "$shim_root" || "${shim_root##*/}" != "$surface_component" || "${shim_parent##*/}" != "hmux-cli-shims" || "$shim_root" == "$legacy_shim_root" ]] \
        || ! _hmux_private_dirs 0 "$shim_parent" "$shim_root"; then
        # Keep a shim root this shell did not accept off PATH.
        [[ "${shim_parent##*/}" == "hmux-cli-shims" ]] && rejected_root="$shim_root"
        shim_parent="$shim_state/hmux-cli-shims"
        shim_root="$shim_parent/$surface_component"
        if [[ "${HOME:-}" != /* ]] || ! _hmux_private_dirs 1 "$shim_state" "$shim_parent" "$shim_root"; then
            if [[ "$command_name" == "claude" ]]; then
                unset HMUX_CLAUDE_WRAPPER_SHIM HMUX_CLAUDE_WRAPPER_SHIM_ROOT
                _HMUX_CLAUDE_WRAPPER_SHIM_VERIFIED=""
            fi
            if [[ -n "$rejected_root" ]]; then
                _hmux_path_prepend_unique_directory_into_reply "$rejected_root" "${PATH-}"
                REPLY="${REPLY#"$rejected_root"}"
                PATH="${REPLY#:}"
                hash -r >/dev/null 2>&1 || rehash >/dev/null 2>&1 || true
            fi
            return 0
        fi
    fi
    local shim_path="$shim_root/$command_name"
    local escaped_wrapper="$wrapper_path"

    escaped_wrapper="${escaped_wrapper//\\/\\\\}"
    escaped_wrapper="${escaped_wrapper//\"/\\\"}"
    escaped_wrapper="${escaped_wrapper//\$/\\\$}"
    escaped_wrapper="${escaped_wrapper//\`/\\\`}"

    /bin/mkdir -p "$shim_root" >/dev/null 2>&1 || return 0
    {
        printf '%s\n' '#!/usr/bin/env bash'
        if [[ "$command_name" == "claude" ]]; then
            printf 'hmux_wrapper="%s"\n' "$escaped_wrapper"
            printf '%s\n' 'if [[ ! -x "$hmux_wrapper" && -n "${HMUX_BUNDLED_CLI_PATH:-}" ]]; then'
            printf '%s\n' '    hmux_candidate="$(dirname "$HMUX_BUNDLED_CLI_PATH")/hmux-claude-wrapper"'
            printf '%s\n' '    if [[ -x "$hmux_candidate" ]]; then'
            printf '%s\n' '        hmux_wrapper="$hmux_candidate"'
            printf '%s\n' '    fi'
            printf '%s\n' 'fi'
            printf '%s\n' 'if [[ ! -x "$hmux_wrapper" ]]; then'
            printf '%s\n' '    hmux_cli="$(command -v hmux 2>/dev/null || true)"'
            printf '%s\n' '    if [[ -n "$hmux_cli" ]]; then'
            printf '%s\n' '        hmux_candidate="$(dirname "$hmux_cli")/hmux-claude-wrapper"'
            printf '%s\n' '        if [[ -x "$hmux_candidate" ]]; then'
            printf '%s\n' '            hmux_wrapper="$hmux_candidate"'
            printf '%s\n' '        fi'
            printf '%s\n' '    fi'
            printf '%s\n' 'fi'
            printf 'export HMUX_CLAUDE_WRAPPER_SHIM=%q\n' "$shim_path"
            printf 'export HMUX_CLAUDE_WRAPPER_SHIM_ROOT=%q\n' "$shim_root"
            printf '%s\n' 'if [[ -x "$hmux_wrapper" ]]; then'
            printf '%s\n' '    exec "$hmux_wrapper" "$@"'
            printf '%s\n' 'fi'
            printf '%s\n' 'hmux_path_without_shim=""'
            printf '%s\n' 'hmux_old_ifs="$IFS"'
            printf '%s\n' 'IFS=:'
            printf '%s\n' 'for hmux_entry in ${PATH:-}; do'
            printf '%s\n' '    if [[ "$hmux_entry" == "$HMUX_CLAUDE_WRAPPER_SHIM_ROOT" || "$hmux_entry" == */hmux-cli-shims/* || "$hmux_entry" == */hmux-cli-shims ]]; then'
            printf '%s\n' '        continue'
            printf '%s\n' '    fi'
            printf '%s\n' '    if [[ -z "$hmux_path_without_shim" ]]; then'
            printf '%s\n' '        hmux_path_without_shim="$hmux_entry"'
            printf '%s\n' '    else'
            printf '%s\n' '        hmux_path_without_shim="$hmux_path_without_shim:$hmux_entry"'
            printf '%s\n' '    fi'
            printf '%s\n' 'done'
            printf '%s\n' 'IFS="$hmux_old_ifs"'
            printf '%s\n' 'export PATH="$hmux_path_without_shim"'
            printf '%s\n' 'exec claude "$@"'
        else
            printf 'exec "%s" "$@"\n' "$escaped_wrapper"
        fi
    # Use zsh's explicit clobber redirection (>|) so hmux always refreshes its
    # own generated shim, even when the user's interactive zsh has `noclobber`
    # set. A plain `>` is refused under noclobber and prints `file exists` on
    # startup (the writer runs again from the _hmux_fix_path precmd hook after
    # the shim already exists). See issue #6714.
    } >|"$shim_path" 2>/dev/null || return 0
    /bin/chmod 0700 "$shim_path" >/dev/null 2>&1 || return 0

    if [[ "$command_name" == "claude" ]]; then
        export HMUX_CLAUDE_WRAPPER_SHIM="$shim_path"
        export HMUX_CLAUDE_WRAPPER_SHIM_ROOT="$shim_root"
        _HMUX_CLAUDE_WRAPPER_SHIM_VERIFIED="$shim_path"
    fi

    _hmux_path_prepend_unique_directory_into_reply "$shim_root" "${PATH-}" "$rejected_root"
    PATH="$REPLY"
    hash -r >/dev/null 2>&1 || rehash >/dev/null 2>&1 || true
}
_hmux_claude_wrapper_command() {
    # Only run a shim this shell wrote into a directory it checked.
    if [[ -n "$_HMUX_CLAUDE_WRAPPER_SHIM_VERIFIED" && "${HMUX_CLAUDE_WRAPPER_SHIM:-}" == "$_HMUX_CLAUDE_WRAPPER_SHIM_VERIFIED" && -x "$_HMUX_CLAUDE_WRAPPER_SHIM_VERIFIED" ]]; then
        "$HMUX_CLAUDE_WRAPPER_SHIM" "$@"
    elif [[ -x "${_HMUX_CLAUDE_WRAPPER:-}" ]]; then
        "$_HMUX_CLAUDE_WRAPPER" "$@"
    else
        command claude "$@"
    fi
}
_hmux_install_cli_wrapper() {
    local command_name="$1"
    local wrapper_variable="$2"
    local wrapper_file="${3:-$command_name}"
    local integration_dir="${HMUX_SHELL_INTEGRATION_DIR:-}"
    if [[ "$command_name" == "claude" && "${HMUX_CLAUDE_INTEGRATION_DISABLED:-0}" == "1" ]]; then
        return 0
    fi
    [[ -n "$integration_dir" ]] || return 0

    integration_dir="${integration_dir%/}"
    local bundle_dir="${integration_dir%/shell-integration}"
    local wrapper_path="$bundle_dir/bin/$wrapper_file"
    [[ -x "$wrapper_path" ]] || return 0

    # Keep the bundled wrapper ahead of later PATH mutations. Install it
    # via eval so an existing alias cannot break parsing.
    typeset -g "$wrapper_variable=$wrapper_path"
    if [[ "$command_name" == "claude" ]]; then
        _hmux_install_cli_command_shim "$command_name" "$wrapper_path"
    fi
    builtin unalias "$command_name" >/dev/null 2>&1 || true
    if [[ "$command_name" == "claude" ]]; then
        eval "$command_name() { _hmux_claude_wrapper_command \"\$@\"; }"
    else
        eval "$command_name() { \"\${$wrapper_variable}\" \"\$@\"; }"
    fi
}
_hmux_install_cli_wrapper claude _HMUX_CLAUDE_WRAPPER hmux-claude-wrapper
_hmux_install_cli_wrapper grok _HMUX_GROK_WRAPPER
_hmux_install_cli_wrapper muse _HMUX_MUSE_WRAPPER

_hmux_normalize_claude_config_dir() {
    [[ -n "${CLAUDE_CONFIG_DIR:-}" && -n "${HOME:-}" ]] || return 0

    local value="$CLAUDE_CONFIG_DIR"
    if [[ "$value" == "~/"* ]]; then
        value="$HOME/${value#~/}"
    fi

    local legacy_root="$HOME/.subrouter/codex/claude"
    local account_root="$HOME/.codex-accounts/claude"
    local suffix candidate

    if [[ "$value" == "$legacy_root" ]]; then
        candidate="$account_root"
    elif [[ "$value" == "$legacy_root/"* ]]; then
        suffix="${value#$legacy_root/}"
        candidate="$account_root/$suffix"
    else
        return 0
    fi

    [[ -d "$candidate" ]] || return 0
    export CLAUDE_CONFIG_DIR="$candidate"
}
_hmux_normalize_claude_config_dir

# Throttle heavy work to avoid prompt latency.
typeset -g _HMUX_PWD_LAST_PWD=""
typeset -g _HMUX_GIT_LAST_PWD=""
typeset -g _HMUX_GIT_LAST_RUN=0
typeset -g _HMUX_GIT_JOB_PID=""
typeset -g _HMUX_GIT_JOB_STARTED_AT=0
typeset -g _HMUX_GIT_FORCE=0
typeset -g _HMUX_GIT_HEAD_LAST_PWD=""
typeset -g _HMUX_GIT_HEAD_PATH=""
typeset -g _HMUX_GIT_HEAD_SIGNATURE=""
typeset -g _HMUX_GIT_HEAD_WATCH_PID=""
# Created on first use by _hmux_set_git_active_pwd, and only while git watching
# is on: the git reporters are its only readers.
typeset -g _HMUX_GIT_ACTIVE_PWD_FILE="${_HMUX_GIT_ACTIVE_PWD_FILE:-}"
typeset -g _HMUX_PR_POLL_PID=""
typeset -g _HMUX_PR_POLL_PWD=""
typeset -g _HMUX_PR_LAST_BRANCH=""
typeset -g _HMUX_PR_NO_PR_BRANCH=""
typeset -g _HMUX_PR_POLL_INTERVAL=45
typeset -g _HMUX_PR_FORCE=0
typeset -g _HMUX_PR_DEBUG=${_HMUX_PR_DEBUG:-0}
typeset -g _HMUX_ASYNC_JOB_TIMEOUT=20
typeset -g _HMUX_LAST_PR_ACTION=""
typeset -g _HMUX_LAST_PR_TARGET=""

typeset -g _HMUX_PORTS_LAST_RUN=0
typeset -g _HMUX_CMD_START=0
typeset -g _HMUX_SHELL_ACTIVITY_LAST=""
typeset -g _HMUX_TTY_NAME=""
typeset -g _HMUX_TTY_REPORTED=0
typeset -g _HMUX_TMUX_PUSH_SIGNATURE=""
typeset -g _HMUX_TMUX_PULL_SIGNATURE=""
typeset -g _HMUX_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=${_HMUX_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT:-0}
# Keep HMUX_SOCKET_CAPABILITY inherited; tmux's global environment is readable
# by clients that were not started inside hmux.
typeset -ga _HMUX_TMUX_SYNC_KEYS=(
    HMUX_BUNDLED_CLI_PATH
    HMUX_BUNDLE_ID
    HMUXD_UNIX_PATH
    HMUXTERM_REPO_ROOT
    HMUX_DEBUG_LOG
    HMUX_LOAD_GHOSTTY_ZSH_INTEGRATION
    HMUX_PORT
    HMUX_PORT_END
    HMUX_PORT_RANGE
    HMUX_REMOTE_DAEMON_ALLOW_LOCAL_BUILD
    HMUX_SHELL_INTEGRATION
    HMUX_SHELL_INTEGRATION_DIR
    HMUX_SOCKET_ENABLE
    HMUX_SOCKET_MODE
    HMUX_SOCKET_PATH
    HMUX_SSH_ATTEMPT_ID
    HMUX_TAB_ID
    HMUX_TAG
    HMUX_TERMINAL_LIFECYCLE_ID
    HMUX_WORKSPACE_ID
)
typeset -ga _HMUX_TMUX_SURFACE_SCOPED_KEYS=(
    HMUX_HISTORY_FILE
    HMUX_PANEL_ID
    HMUX_SURFACE_ID
)

_hmux_tmux_sync_key_is_managed() {
    local candidate="$1"
    local key
    for key in "${_HMUX_TMUX_SYNC_KEYS[@]}"; do
        [[ "$key" == "$candidate" ]] && return 0
    done
    return 1
}

# Sets REPLY rather than printing, so prompt hooks do not fork a subshell.
_hmux_tmux_shell_env_signature_into_reply() {
    local key value
    local -a parts
    for key in "${_HMUX_TMUX_SYNC_KEYS[@]}"; do
        value="${(P)key}"
        [[ -n "$value" ]] || continue
        parts+=("${key}=${value}")
    done
    REPLY="${(j:\x1f:)parts}"
}

_hmux_tmux_shell_env_signature() {
    local REPLY
    _hmux_tmux_shell_env_signature_into_reply
    print -r -- "$REPLY"
}

# A published environment only matters to a running default tmux server; a
# server started later inherits it from the shell that starts it. Checking the
# socket keeps every prompt and command from spawning a tmux client that can
# only fail when no server is running. tmux ignores a TMUX_TMPDIR that does not
# resolve and falls back to /tmp, so the socket path follows the same rule.
_hmux_tmux_default_server_socket_into_reply() {
    local socket_root="/tmp"
    [[ -n "${TMUX_TMPDIR:-}" && -e "$TMUX_TMPDIR" ]] && socket_root="$TMUX_TMPDIR"
    REPLY="${socket_root%/}/tmux-${UID}/default"
}

_hmux_tmux_default_server_running() {
    local REPLY
    _hmux_tmux_default_server_socket_into_reply
    [[ -S "$REPLY" ]]
}

# An exited tmux server can leave its socket behind. When tmux reports that
# nothing is listening there, a marker next to the socket records it as dead, so
# later prompts and shells skip the tmux spawn until a new server rebinds the
# socket (which makes the socket newer than the marker). Other failures, such as
# an interrupted client, leave no marker. The socket directory is private to the
# user, so the marker cannot be redirected through a planted symlink.
_hmux_tmux_error_means_no_server() {
    [[ "$1" == *"no server running"* || "$1" == *"error connecting"* || "$1" == *"Connection refused"* ]]
}

_hmux_tmux_publish_hmux_environment() {
    [[ -z "$TMUX" ]] || return 0
    command -v tmux >/dev/null 2>&1 || return 0

    local REPLY
    _hmux_tmux_default_server_socket_into_reply
    local server_socket="$REPLY"
    [[ -S "$server_socket" ]] || return 0
    local stale_marker="${server_socket}.hmux-unreachable"
    [[ -e "$stale_marker" && ! "$server_socket" -nt "$stale_marker" ]] && return 0

    _hmux_tmux_shell_env_signature_into_reply
    local signature="$REPLY"
    [[ -n "$signature" ]] || return 0
    [[ "$signature" == "$_HMUX_TMUX_PUSH_SIGNATURE" ]] && return 0

    local key value tmux_error
    for key in "${_HMUX_TMUX_SYNC_KEYS[@]}"; do
        value="${(P)key}"
        [[ -n "$value" ]] || continue
        if ! tmux_error="$(tmux set-environment -g "$key" "$value" 2>&1 >/dev/null)"; then
            if _hmux_tmux_error_means_no_server "$tmux_error"; then
                : 2>/dev/null >| "$stale_marker"
            fi
            return 0
        fi
    done

    for key in "${_HMUX_TMUX_SURFACE_SCOPED_KEYS[@]}"; do
        tmux set-environment -gu "$key" >/dev/null 2>&1 || return 0
    done

    _HMUX_TMUX_PUSH_SIGNATURE="$signature"
}

_hmux_tmux_refresh_hmux_environment() {
    [[ -n "$TMUX" ]] || return 0
    command -v tmux >/dev/null 2>&1 || return 0

    local key did_change=0
    for key in "${_HMUX_TMUX_SURFACE_SCOPED_KEYS[@]}"; do
        if [[ -n "${(P)key}" ]]; then
            unset "$key"
            did_change=1
        fi
    done

    local output
    output="$(tmux show-environment 2>/dev/null)" || return 0

    local line filtered=""
    while IFS= read -r line; do
        [[ "$line" == HMUX_* ]] || continue
        key="${line%%=*}"
        _hmux_tmux_sync_key_is_managed "$key" || continue
        filtered+="${line}"$'\n'
    done <<< "$output"

    [[ -n "$filtered" ]] || return 0
    [[ "$filtered" == "$_HMUX_TMUX_PULL_SIGNATURE" ]] && (( ! did_change )) && return 0

    local value
    while IFS= read -r line; do
        [[ "$line" == HMUX_* ]] || continue
        key="${line%%=*}"
        _hmux_tmux_sync_key_is_managed "$key" || continue
        value="${line#*=}"
        if [[ "${(P)key}" != "$value" ]]; then
            export "$key=$value"
            did_change=1
        fi
    done <<< "$filtered"

    _HMUX_TMUX_PULL_SIGNATURE="$filtered"
    if (( did_change )); then
        _HMUX_TTY_REPORTED=0
        _HMUX_SHELL_ACTIVITY_LAST=""
        _HMUX_PWD_LAST_PWD=""
        _HMUX_GIT_LAST_PWD=""
        _HMUX_GIT_HEAD_LAST_PWD=""
        _HMUX_GIT_HEAD_PATH=""
        _HMUX_GIT_HEAD_SIGNATURE=""
        _HMUX_GIT_FORCE=1
        _HMUX_PR_FORCE=1
        _hmux_stop_pr_poll_loop
        _hmux_stop_git_head_watch
    fi
}

_hmux_tmux_sync_hmux_environment() {
    if [[ -n "$TMUX" ]]; then
        _hmux_tmux_refresh_hmux_environment
    else
        _hmux_tmux_publish_hmux_environment
    fi
}

_hmux_prepend_job_table_guard_to_function() {
    local fn_name="$1"
    (( $+functions[$fn_name] )) || return 0
    local saved_var="__hmux_${fn_name}_saved_status"
    [[ "${functions[$fn_name]}" == *"$saved_var"* ]] && return 0

    functions[$fn_name]="builtin local ${saved_var}=\$?
_hmux_zsh_job_table_saturated && builtin return 0
_hmux_restore_status \"\$${saved_var}\"
${functions[$fn_name]}"
}

# Usage: _hmux_insert_job_table_guard_after_declaration FN TARGET GUARD [TARGET GUARD]...
# Inserts each GUARD after the first nested declaration of its TARGET inside FN,
# walking FN's body once for every pair.
_hmux_insert_job_table_guard_after_declaration() {
    builtin emulate -L zsh -o extended_glob -o no_aliases

    local fn_name="$1"
    shift
    (( $+functions[$fn_name] )) || return 0

    local body="${functions[$fn_name]}"
    local -A pending
    while (( $# >= 2 )); do
        [[ "$body" == *"$2"* ]] || pending[$1]="$2"
        shift 2
    done
    (( ${#pending} )) || return 0

    local -a lines patched_lines declaration_names
    lines=("${(@f)body}")
    local line trimmed declaration candidate
    local inserted=0

    for line in "${lines[@]}"; do
        patched_lines+=("$line")
        (( ${#pending} )) || continue

        trimmed="${line##[[:space:]]#}"
        [[ "$trimmed" == *"{"* ]] || continue

        declaration="${trimmed%%\{}"
        declaration="${declaration//\(\)/ }"
        if [[ "$declaration" == function[[:space:]]* ]]; then
            declaration="${declaration#function}"
        fi
        declaration_names=("${(@z)declaration}")

        for candidate in "${declaration_names[@]}"; do
            if (( ${+pending[$candidate]} )); then
                patched_lines+=("${(@f)pending[$candidate]}")
                unset "pending[$candidate]"
                inserted=1
            fi
        done
    done

    (( inserted )) || return 0
    functions[$fn_name]="${(F)patched_lines}"
}

_hmux_patch_ghostty_job_table_guard() {
    local guard_precmd=$'        builtin local __hmux__ghostty_precmd_saved_status=$?\n        _hmux_zsh_job_table_saturated && builtin return 0\n        _hmux_restore_status "$__hmux__ghostty_precmd_saved_status"'
    local guard_preexec=$'        builtin local __hmux__ghostty_preexec_saved_status=$?\n        _hmux_zsh_job_table_saturated && builtin return 0\n        _hmux_restore_status "$__hmux__ghostty_preexec_saved_status"'
    local guard_zle_init=$'          builtin local __hmux__ghostty_zle_line_init_saved_status=$?\n          _hmux_zsh_job_table_saturated && builtin return 0\n          _hmux_restore_status "$__hmux__ghostty_zle_line_init_saved_status"'
    local guard_zle_finish=$'          builtin local __hmux__ghostty_zle_line_finish_saved_status=$?\n          _hmux_zsh_job_table_saturated && builtin return 0\n          _hmux_restore_status "$__hmux__ghostty_zle_line_finish_saved_status"'
    local guard_zle_keymap=$'          builtin local __hmux__ghostty_zle_keymap_select_saved_status=$?\n          _hmux_zsh_job_table_saturated && builtin return 0\n          _hmux_restore_status "$__hmux__ghostty_zle_keymap_select_saved_status"'

    # Patch deferred definitions before Ghostty's first precmd installs and
    # invokes its live hook functions.
    if (( $+functions[_ghostty_deferred_init] )); then
        _hmux_insert_job_table_guard_after_declaration _ghostty_deferred_init \
            _ghostty_precmd "$guard_precmd" \
            _ghostty_preexec "$guard_preexec" \
            _ghostty_zle_line_init "$guard_zle_init" \
            _ghostty_zle_line_finish "$guard_zle_finish" \
            _ghostty_zle_keymap_select "$guard_zle_keymap"
    fi

    _hmux_prepend_job_table_guard_to_function _ghostty_precmd
    _hmux_prepend_job_table_guard_to_function _ghostty_preexec
    _hmux_prepend_job_table_guard_to_function _ghostty_zle_line_init
    _hmux_prepend_job_table_guard_to_function _ghostty_zle_line_finish
    _hmux_prepend_job_table_guard_to_function _ghostty_zle_keymap_select
}
_hmux_patch_ghostty_job_table_guard

# Resolve the HEAD file path without invoking git (fast; works for worktrees).
# Sets REPLY (empty when not in a repository) so prompt hooks need no subshell.
_hmux_git_resolve_head_path_into_reply() {
    REPLY=""
    local dir="${1:-$PWD}"
    while true; do
        if [[ -d "$dir/.git" ]]; then
            REPLY="$dir/.git/HEAD"
            return 0
        fi
        if [[ -f "$dir/.git" ]]; then
            local line gitdir
            line="$(<"$dir/.git")"
            if [[ "$line" == gitdir:* ]]; then
                gitdir="${line#gitdir:}"
                gitdir="${gitdir## }"
                gitdir="${gitdir%% }"
                [[ -n "$gitdir" ]] || return 1
                [[ "$gitdir" != /* ]] && gitdir="$dir/$gitdir"
                REPLY="$gitdir/HEAD"
                return 0
            fi
        fi
        [[ "$dir" == "/" || -z "$dir" ]] && break
        dir="${dir:h}"
    done
    return 1
}

_hmux_git_resolve_head_path() {
    local REPLY
    _hmux_git_resolve_head_path_into_reply "$@" || return 1
    print -r -- "$REPLY"
}

_hmux_git_resolve_git_dir() {
    local repo_path="${1:-$PWD}"
    local head_path
    head_path="$(_hmux_git_resolve_head_path "$repo_path" 2>/dev/null || true)"
    [[ -n "$head_path" ]] || return 1
    print -r -- "${head_path:h}"
}

# Sets REPLY rather than printing, so the per-second HEAD watcher does not fork
# a subshell on every poll.
_hmux_git_head_signature_into_reply() {
    REPLY=""
    local head_path="$1"
    [[ -n "$head_path" && -r "$head_path" ]] || return 1
    local line=""
    if IFS= read -r line < "$head_path"; then
        REPLY="$line"
        return 0
    fi
    return 1
}

_hmux_git_head_signature() {
    local REPLY
    _hmux_git_head_signature_into_reply "$1" || return 1
    print -r -- "$REPLY"
}

_hmux_git_branch_for_path() {
    local repo_path="$1"
    local head_path="" head_line="" prefix="ref: refs/heads/"
    head_path="$(_hmux_git_resolve_head_path "$repo_path" 2>/dev/null || true)"
    [[ -n "$head_path" && -r "$head_path" ]] || return 1
    head_line="$(<"$head_path")"
    [[ "$head_line" == "$prefix"* ]] || return 1
    print -r -- "${head_line#$prefix}"
}

_hmux_set_git_active_pwd() {
    local active_pwd="$1"
    [[ -n "$active_pwd" ]] || return 0
    if [[ -z "${_HMUX_GIT_ACTIVE_PWD_FILE:-}" ]]; then
        # Create it only from the prompt in the shell itself: chpwd also fires in
        # subshells (`$(cd x && pwd)` in startup files), whose copy would leak.
        [[ "${2:-}" == "create" ]] || return 0
        (( ${ZSH_SUBSHELL:-0} == 0 )) || return 0
        [[ "${HMUX_NO_GIT_WATCH:-}" == "1" ]] && return 0
        _HMUX_GIT_ACTIVE_PWD_FILE="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/hmux-git-active-pwd.XXXXXX" 2>/dev/null)"
        [[ -n "$_HMUX_GIT_ACTIVE_PWD_FILE" ]] || return 0
    fi
    print -r -- "$active_pwd" >| "$_HMUX_GIT_ACTIVE_PWD_FILE" 2>/dev/null || true
}

_hmux_git_report_path_is_active() {
    local repo_path="$1"
    [[ -n "$repo_path" ]] || return 1
    [[ -n "${_HMUX_GIT_ACTIVE_PWD_FILE:-}" ]] || return 0
    [[ -r "$_HMUX_GIT_ACTIVE_PWD_FILE" ]] || return 0

    local active_pwd=""
    IFS= read -r active_pwd < "$_HMUX_GIT_ACTIVE_PWD_FILE" || active_pwd=""
    # No recorded cwd yet, or the report targets the current cwd exactly: allow.
    [[ -z "$active_pwd" || "$repo_path" == "$active_pwd" ]] && return 0

    # Otherwise the report is valid only when the current cwd is in the SAME
    # repository as repo_path. This keeps live branch updates flowing after an
    # in-repo `cd pkg` (the HEAD watch still reports the preexec watch_pwd) while
    # still dropping a report once the shell has left the repo entirely (the
    # stale-branch case). Resolve both HEAD paths without invoking git and compare.
    local repo_head active_head
    repo_head="$(_hmux_git_resolve_head_path "$repo_path" 2>/dev/null || true)"
    active_head="$(_hmux_git_resolve_head_path "$active_pwd" 2>/dev/null || true)"
    [[ -n "$repo_head" && "$repo_head" == "$active_head" ]]
}

# Sets REPLY (empty when there is nothing to report) without forking.
_hmux_report_tty_payload_into_reply() {
    REPLY=""
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    [[ -n "$_HMUX_TTY_NAME" ]] || return 0

    local payload="report_tty $_HMUX_TTY_NAME --tab=$HMUX_TAB_ID"
    if [[ -z "$TMUX" ]]; then
        [[ -n "$HMUX_PANEL_ID" ]] || return 0
        payload+=" --panel=$HMUX_PANEL_ID"
    fi

    REPLY="$payload"
}

_hmux_report_tty_payload() {
    local REPLY
    _hmux_report_tty_payload_into_reply
    [[ -n "$REPLY" ]] || return 0
    print -r -- "$REPLY"
}

_hmux_report_tty_once() {
    # Send the TTY name to the app once per session so the batched port scanner
    # knows which TTY belongs to this panel.
    (( _HMUX_TTY_REPORTED )) && return 0
    _hmux_has_port_scan_transport || return 0

    if _hmux_socket_is_unix; then
        local REPLY
        _hmux_report_tty_payload_into_reply
        local payload="$REPLY"
        [[ -n "$payload" ]] || return 0
        # Batch the first ports kick behind the registration in the same
        # child: the scanner drops kicks for unregistered TTYs, and two
        # detached children can connect out of order. Latch only after the
        # send was actually enqueued so a cap-dropped registration retries.
        if [[ -n "$HMUX_TAB_ID" && -n "$HMUX_PANEL_ID" ]]; then
            _hmux_send_bg "$payload" "ports_kick --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID --reason=command" || return 0
        else
            _hmux_send_bg "$payload" || return 0
        fi
        _HMUX_TTY_REPORTED=1
    else
        [[ -n "$_HMUX_TTY_NAME" ]] || return 0
        # Keep the first relay TTY report synchronous so the server can resolve
        # the target surface before command-start kicks begin their scan burst.
        _hmux_report_tty_via_relay || return 0
        _HMUX_TTY_REPORTED=1
    fi
}

_hmux_report_shell_activity_state() {
    local state="$1"
    [[ -n "$state" ]] || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    if _hmux_socket_is_unix; then
        [[ -n "$HMUX_PANEL_ID" ]] || return 0
    fi
    [[ "$_HMUX_SHELL_ACTIVITY_LAST" == "$state" ]] && return 0
    _HMUX_SHELL_ACTIVITY_LAST="$state"
    if _hmux_socket_is_unix; then
        local payload="report_shell_state $state --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID"
        if [[ -n "${HMUX_TERMINAL_LIFECYCLE_ID:-}" ]]; then
            payload+=" --terminal-lifecycle-id=$HMUX_TERMINAL_LIFECYCLE_ID"
        fi
        _hmux_send_bg "$payload" \
            || _HMUX_SHELL_ACTIVITY_LAST=""
    else
        _hmux_report_shell_activity_state_via_relay "$state" || _HMUX_SHELL_ACTIVITY_LAST=""
    fi
}

_hmux_reset_terminal_keyboard_protocols() {
    [[ -t 1 || -n "${HMUX_TEST_FORCE_KEYBOARD_RESET:-}${HMUX_TEST_FORCE_KITTY_RESET:-}" ]] || return 0
    # A crashed TUI may leave keyboard protocol state pushed. At a fresh shell
    # prompt, return terminal input encoding to plain readline bytes.
    printf '\033[>m\033[<8u'
}

_hmux_reset_terminal_leftover_modes() {
    [[ -t 1 || -n "${HMUX_TEST_FORCE_KEYBOARD_RESET:-}" ]] || return 0
    # A TUI killed mid-run (SIGKILL, a crash) leaves its modes on: mouse
    # reporting types reports like 35;1;13M at the prompt. The shell is the
    # foreground job here, before its line editor turns bracketed paste back
    # on. A hidden cursor comes back. Cursor-key mode (?1) stays:
    # zle sets it after this hook.
    printf '\033[?9l\033[?1000l\033[?1002l\033[?1003l\033[?1005l\033[?1006l\033[?1015l\033[?1016l\033[?1004l\033[?2004l\033[?25h'
    # Leaving the alternate screen restores a saved cursor; ESC 7 makes that
    # the prompt's own spot on Ghostty's primary screen. tmux and screen keep
    # the 1049 cursor apart from ESC 7, so there the prompt would jump.
    [[ -n "${TMUX:-}${STY:-}" ]] || printf '\033\067\033[?1049l'
}

_hmux_ports_kick() {
    local reason="${1:-command}"
    # Lightweight: just tell the app to run a batched scan for this panel.
    # The app coalesces kicks across all panels and runs a single ps+lsof.
    _hmux_has_port_scan_transport || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    if _hmux_socket_is_unix; then
        [[ -n "$HMUX_PANEL_ID" ]] || return 0
    fi
    _HMUX_PORTS_LAST_RUN="${EPOCHSECONDS:-$SECONDS}"
    if _hmux_socket_is_unix; then
        _hmux_send_bg "ports_kick --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID --reason=$reason"
    else
        _hmux_ports_kick_via_relay "$reason"
    fi
}

_hmux_report_git_branch_for_path() {
    local repo_path="$1"
    [[ "${HMUX_NO_GIT_WATCH:-}" == "1" ]] && return 0
    [[ -n "$repo_path" ]] || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    if _hmux_socket_is_unix; then
        [[ -n "$HMUX_PANEL_ID" ]] || return 0
    fi
    _hmux_git_report_path_is_active "$repo_path" || return 0

    local branch dirty_opt="--status=unknown"
    branch="$(_hmux_git_branch_for_path "$repo_path" 2>/dev/null || true)"
    _hmux_git_report_path_is_active "$repo_path" || return 0
    if [[ -n "$branch" ]]; then
        if _hmux_socket_is_unix; then
            _hmux_send "report_git_branch $branch $dirty_opt --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID"
        else
            _hmux_report_git_branch_via_relay "$branch" || true
        fi
    else
        if _hmux_socket_is_unix; then
            _hmux_send "clear_git_branch --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID"
        else
            _hmux_clear_git_branch_via_relay || true
        fi
    fi
}

_hmux_record_pr_command_hint() {
    local cmd="$1"
    _HMUX_LAST_PR_ACTION=""
    _HMUX_LAST_PR_TARGET=""

    local -a words
    words=("${(z)cmd}")

    local index=1
    local word base
    while (( index <= ${#words} )); do
        word="${words[index]}"

        case "$word" in
            *=*)
                index=$(( index + 1 ))
                continue ;;
            exec|command|builtin|noglob|time)
                index=$(( index + 1 ))
                continue ;;
            env)
                index=$(( index + 1 ))
                while (( index <= ${#words} )); do
                    word="${words[index]}"
                    case "$word" in
                        -*|*=*)
                            index=$(( index + 1 ))
                            continue ;;
                    esac
                    break
                done
                continue ;;
        esac

        base="${word:t}"
        [[ "$base" == "gh" ]] || return 0
        index=$(( index + 1 ))
        break
    done

    (( index + 1 <= ${#words} )) || return 0
    [[ "${words[index]}" == "pr" ]] || return 0
    local action="${words[index + 1]:l}"
    case "$action" in
        merge|close|reopen|create|checkout|ready|edit|view)
            _HMUX_LAST_PR_ACTION="$action" ;;
        *)
            return 0 ;;
    esac

    index=$(( index + 2 ))
    while (( index <= ${#words} )); do
        word="${words[index]}"
        case "$word" in
            --*=*)
                index=$(( index + 1 ))
                continue ;;
            --*)
                index=$(( index + 2 ))
                continue ;;
            -*)
                index=$(( index + 1 ))
                continue ;;
            *)
                _HMUX_LAST_PR_TARGET="$word"
                break ;;
        esac
    done
}

_hmux_emit_pr_command_hint() {
    [[ "${HMUX_NO_PR_WATCH:-}" == "1" ]] && return 0
    [[ -S "$HMUX_SOCKET_PATH" ]] || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    [[ -n "$HMUX_PANEL_ID" ]] || return 0
    [[ -n "$_HMUX_LAST_PR_ACTION" ]] || return 0

    local payload="report_pr_action $_HMUX_LAST_PR_ACTION --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID"
    if [[ -n "$_HMUX_LAST_PR_TARGET" ]]; then
        local quoted_target="${_HMUX_LAST_PR_TARGET//\"/\\\"}"
        payload+=" --target=\"$quoted_target\""
    fi
    _hmux_send_bg "$payload"
    _HMUX_LAST_PR_ACTION=""
    _HMUX_LAST_PR_TARGET=""
}

_hmux_clear_pr_for_panel() {
    [[ "${HMUX_NO_GIT_WATCH:-}" == "1" ]] && return 0
    [[ -S "$HMUX_SOCKET_PATH" ]] || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    [[ -n "$HMUX_PANEL_ID" ]] || return 0
    _hmux_send_bg "clear_pr --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID"
}

_hmux_pr_output_indicates_no_pull_request() {
    local output="${1:l}"
    [[ "$output" == *"no pull requests found"* \
        || "$output" == *"no pull request found"* \
        || "$output" == *"no pull requests associated"* \
        || "$output" == *"no pull request associated"* ]]
}

_hmux_git_config_resolve_include_path() {
    local path="$1" config_dir="$2"
    case "$path" in
        "~")
            printf '%s\n' "$HOME" ;;
        "~/"*)
            printf '%s/%s\n' "$HOME" "${path#~/}" ;;
        /*)
            printf '%s\n' "$path" ;;
        *)
            printf '%s/%s\n' "$config_dir" "$path" ;;
    esac
}

_hmux_git_config_gitdir_pattern_matches() {
    local pattern="$1" repo_path="$2" git_dir="$3" common_dir="$4" case_insensitive="$5"
    local expanded="$pattern" candidate cmp_candidate cmp_pattern prefix

    case "$expanded" in
        "~")
            expanded="$HOME" ;;
        "~/"*)
            expanded="$HOME/${expanded#~/}" ;;
    esac
    if [[ "$expanded" == */ ]]; then
        prefix="$expanded"
        [[ "$case_insensitive" == "1" ]] && prefix="$(printf '%s' "$prefix" | tr '[:upper:]' '[:lower:]')"
        for candidate in "$git_dir" "$common_dir" "$repo_path"; do
            cmp_candidate="$candidate"
            [[ "$case_insensitive" == "1" ]] && cmp_candidate="$(printf '%s' "$cmp_candidate" | tr '[:upper:]' '[:lower:]')"
            [[ "$cmp_candidate" == "${prefix%/}" || "$cmp_candidate/" == "$prefix"* ]] && return 0
        done
        return 1
    fi
    if [[ "$expanded" == */'**' ]]; then
        prefix="${expanded%/\*\*}/"
        [[ "$case_insensitive" == "1" ]] && prefix="$(printf '%s' "$prefix" | tr '[:upper:]' '[:lower:]')"
        for candidate in "$git_dir" "$common_dir" "$repo_path"; do
            cmp_candidate="$candidate"
            [[ "$case_insensitive" == "1" ]] && cmp_candidate="$(printf '%s' "$cmp_candidate" | tr '[:upper:]' '[:lower:]')"
            [[ "$cmp_candidate" == "${prefix%/}" || "$cmp_candidate/" == "$prefix"* ]] && return 0
        done
        return 1
    fi

    cmp_pattern="$expanded"
    [[ "$case_insensitive" == "1" ]] && cmp_pattern="$(printf '%s' "$cmp_pattern" | tr '[:upper:]' '[:lower:]')"
    for candidate in "$git_dir" "$common_dir" "$repo_path"; do
        cmp_candidate="$candidate"
        [[ "$case_insensitive" == "1" ]] && cmp_candidate="$(printf '%s' "$cmp_candidate" | tr '[:upper:]' '[:lower:]')"
        [[ "$cmp_candidate" == $cmp_pattern || "$cmp_candidate/" == $cmp_pattern ]] && return 0
    done
    return 1
}

_hmux_git_config_include_condition_matches() {
    local condition="$1" repo_path="$2" git_dir="$3" common_dir="$4"
    local lower pattern
    lower="$(printf '%s' "$condition" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        gitdir/i:*)
            pattern="${condition#gitdir/i:}"
            _hmux_git_config_gitdir_pattern_matches "$pattern" "$repo_path" "$git_dir" "$common_dir" 1 ;;
        gitdir:*)
            pattern="${condition#gitdir:}"
            _hmux_git_config_gitdir_pattern_matches "$pattern" "$repo_path" "$git_dir" "$common_dir" 0 ;;
        *)
            return 1 ;;
    esac
}

_hmux_git_origin_url_read_config_file() {
    local repo_path="$1" git_dir="$2" common_dir="$3" config_file="$4"
    local config_dir="" output=""
    local kind="" entry_payload="" entry_value="" include_path=""

    [[ -r "$config_file" ]] || return 0
    case "$_hmux_git_origin_url_seen" in
        *$'\n'"$config_file"$'\n'*) return 0 ;;
    esac
    _hmux_git_origin_url_depth=$(( _hmux_git_origin_url_depth + 1 ))
    [[ "$_hmux_git_origin_url_depth" -le 32 ]] || return 0
    _hmux_git_origin_url_seen+="$config_file"$'\n'

    config_dir="$(dirname "$config_file")"
    output="$(awk '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        function strip_inline_comment(s, i, c, out, previous_was_space, in_quote, escaped) {
            out = ""
            previous_was_space = 1
            in_quote = 0
            escaped = 0
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (escaped) {
                    out = out c
                    escaped = 0
                    previous_was_space = (c ~ /[[:space:]]/)
                    continue
                }
                if (in_quote && c == "\\") {
                    out = out c
                    escaped = 1
                    previous_was_space = 0
                    continue
                }
                if (c == "\"") {
                    out = out c
                    in_quote = !in_quote
                    previous_was_space = 0
                    continue
                }
                if (!in_quote && previous_was_space && (c == "#" || c == ";")) {
                    break
                }
                out = out c
                previous_was_space = (c ~ /[[:space:]]/)
            }
            return out
        }
        function unquote_config_value(s, i, c, out, escaped) {
            s = trim(s)
            if (length(s) >= 2 && substr(s, 1, 1) == "\"" && substr(s, length(s), 1) == "\"") {
                out = ""
                escaped = 0
                for (i = 2; i < length(s); i++) {
                    c = substr(s, i, 1)
                    if (escaped) {
                        out = out c
                        escaped = 0
                        continue
                    }
                    if (c == "\\") {
                        escaped = 1
                        continue
                    }
                    out = out c
                }
                if (escaped) {
                    out = out "\\"
                }
                return out
            }
            return s
        }
        function path_value(line) {
            sub(/^[^=]*=/, "", line)
            return unquote_config_value(line)
        }
        {
            line = strip_inline_comment($0)
            trimmed = trim(line)
            if (trimmed ~ /^\[remote[[:space:]]+"origin"\][[:space:]]*$/) {
                section = "remote"
                condition = ""
                next
            }
            if (trimmed == "[include]") {
                section = "include"
                condition = ""
                next
            }
            if (trimmed ~ /^\[includeIf[[:space:]]+"/) {
                section = "includeIf"
                condition = trimmed
                sub(/^\[includeIf[[:space:]]+"/, "", condition)
                sub(/"\][[:space:]]*$/, "", condition)
                next
            }
            if (trimmed ~ /^\[/) {
                section = ""
                condition = ""
                next
            }
            if (section == "remote" && line ~ /^[[:space:]]*url[[:space:]]*=/) {
                print "remote\t" path_value(line) "\t"
            }
            if (section == "include" && line ~ /^[[:space:]]*path[[:space:]]*=/) {
                print "include\t" path_value(line) "\t"
            }
            if (section == "includeIf" && line ~ /^[[:space:]]*path[[:space:]]*=/) {
                print "includeIf\t" condition "\t" path_value(line)
            }
        }
    ' "$config_file" 2>/dev/null)"

    while IFS=$'\t' read -r kind entry_payload entry_value; do
        case "$kind" in
            remote)
                [[ -n "$entry_payload" ]] && _hmux_git_origin_url_result="$entry_payload" ;;
            include)
                include_path="$(_hmux_git_config_resolve_include_path "$entry_payload" "$config_dir")"
                [[ -r "$include_path" ]] && _hmux_git_origin_url_read_config_file "$repo_path" "$git_dir" "$common_dir" "$include_path" ;;
            includeIf)
                if _hmux_git_config_include_condition_matches "$entry_payload" "$repo_path" "$git_dir" "$common_dir"; then
                    include_path="$(_hmux_git_config_resolve_include_path "$entry_value" "$config_dir")"
                    [[ -r "$include_path" ]] && _hmux_git_origin_url_read_config_file "$repo_path" "$git_dir" "$common_dir" "$include_path"
                fi ;;
        esac
    done <<< "$output"
}

_hmux_git_origin_url_from_config_files() {
    local repo_path="$1" git_dir="$2" common_dir="$3"
    local _hmux_git_origin_url_seen=$'\n'
    local _hmux_git_origin_url_depth=0
    local _hmux_git_origin_url_result=""

    [[ -r "$common_dir/config" ]] && _hmux_git_origin_url_read_config_file "$repo_path" "$git_dir" "$common_dir" "$common_dir/config"
    [[ "$git_dir" != "$common_dir" && -r "$git_dir/config" ]] && _hmux_git_origin_url_read_config_file "$repo_path" "$git_dir" "$common_dir" "$git_dir/config"
    [[ -n "$_hmux_git_origin_url_result" ]] && printf '%s\n' "$_hmux_git_origin_url_result"
}

_hmux_github_repo_slug_for_path() {
    local repo_path="$1"
    local git_dir="" common_dir="" remote_url="" path_part=""
    [[ -n "$repo_path" ]] || return 0

    git_dir="$(_hmux_git_resolve_git_dir "$repo_path" 2>/dev/null || true)"
    [[ -n "$git_dir" ]] || return 0
    common_dir="$git_dir"
    if [[ -r "$git_dir/commondir" ]]; then
        common_dir="$(<"$git_dir/commondir")"
        common_dir="${common_dir## }"
        common_dir="${common_dir%% }"
        [[ "$common_dir" != /* ]] && common_dir="$git_dir/$common_dir"
    fi
    remote_url="$(_hmux_git_origin_url_from_config_files "$repo_path" "$git_dir" "$common_dir")"
    [[ -n "$remote_url" ]] || return 0

    case "$remote_url" in
        git@github.com:*)
            path_part="${remote_url#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            path_part="${remote_url#ssh://git@github.com/}"
            ;;
        https://github.com/*)
            path_part="${remote_url#https://github.com/}"
            ;;
        http://github.com/*)
            path_part="${remote_url#http://github.com/}"
            ;;
        git://github.com/*)
            path_part="${remote_url#git://github.com/}"
            ;;
        *)
            return 0
            ;;
    esac

    path_part="${path_part%.git}"
    [[ "$path_part" == */* ]] || return 0
    print -r -- "$path_part"
}

# Sets REPLY to the PR watcher's state directory. Pass 1 to create it when
# missing. Fails unless the path is a real directory that this user owns and
# nobody else can write, so no state file lands in a place another local
# account prepared, as the shared /tmp allows.
_hmux_pr_state_dir() {
    builtin emulate -L zsh
    local dir="${${TMPDIR:-/tmp}%/}/hmux-pr-${EUID}"
    if [[ "${1:-0}" == 1 && ! -e "$dir" && ! -L "$dir" ]]; then
        /bin/mkdir -m 700 -- "$dir" >/dev/null 2>&1 || true
    fi
    # Glob qualifiers inspect the link itself: a directory, owned by this
    # user, without group or other write permission.
    local -a private_dir
    private_dir=( "$dir"(N/Uf:go-w:) )
    (( ${#private_dir} )) || return 1
    _hmux_private_path_chain "$dir" || return 1
    REPLY="$dir"
}

_hmux_pr_cache_prefix() {
    [[ -n "$HMUX_PANEL_ID" ]] || return 1
    local REPLY
    _hmux_pr_state_dir 1 || return 1
    print -r -- "$REPLY/cache-${HMUX_PANEL_ID}"
}

_hmux_pr_force_signal_path() {
    [[ -n "$HMUX_PANEL_ID" ]] || return 1
    local REPLY
    _hmux_pr_state_dir 1 || return 1
    print -r -- "$REPLY/force-${HMUX_PANEL_ID}"
}

_hmux_pr_debug_log() {
    (( _HMUX_PR_DEBUG )) || return 0

    local branch="$1"
    local event="$2"
    local now="${EPOCHSECONDS:-$SECONDS}"
    local REPLY
    _hmux_pr_state_dir 1 || return 0
    printf '%s\tbranch=%s\tevent=%s\n' "$now" "$branch" "$event" >>| "$REPLY/debug.log"
}

_hmux_pr_cache_clear() {
    # Runs on every prompt while git watching is off, so only spawn rm when a
    # cache file is actually there (it only exists while PR watching is on).
    local REPLY
    if [[ -n "$HMUX_PANEL_ID" ]] && _hmux_pr_state_dir; then
        local prefix="$REPLY/cache-${HMUX_PANEL_ID}"
        local cache_file
        local -a cache_files
        for cache_file in \
            "${prefix}.branch" \
            "${prefix}.repo" \
            "${prefix}.result" \
            "${prefix}.timestamp" \
            "${prefix}.no-pr-branch"; do
            [[ -e "$cache_file" || -L "$cache_file" ]] && cache_files+=("$cache_file")
        done
        if (( ${#cache_files} )); then
            /bin/rm -f -- "${cache_files[@]}" >/dev/null 2>&1 || true
        fi
    fi

    _HMUX_PR_LAST_BRANCH=""
    _HMUX_PR_NO_PR_BRANCH=""
}

_hmux_pr_request_probe() {
    local signal_path=""
    signal_path="$(_hmux_pr_force_signal_path 2>/dev/null || true)"
    [[ -n "$signal_path" ]] || return 0
    : >| "$signal_path"
}

_hmux_report_pr_for_path() {
    local repo_path="$1"
    local force_probe="${2:-0}"
    if [[ "${HMUX_NO_PR_WATCH:-}" == "1" ]]; then
        _hmux_pr_cache_clear
        _hmux_clear_pr_for_panel
        return 0
    fi
    [[ -n "$repo_path" ]] || {
        _hmux_pr_cache_clear
        _hmux_clear_pr_for_panel
        return 0
    }
    [[ -d "$repo_path" ]] || {
        _hmux_pr_cache_clear
        _hmux_clear_pr_for_panel
        return 0
    }
    [[ -S "$HMUX_SOCKET_PATH" ]] || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    [[ -n "$HMUX_PANEL_ID" ]] || return 0

    local branch repo_slug="" gh_output="" gh_error="" err_file="" number state url status_opt="" gh_status
    local now="${EPOCHSECONDS:-$SECONDS}"
    local prefix="" branch_file="" repo_file="" result_file="" timestamp_file="" no_pr_branch_file=""
    local cache_branch="" cache_result="" cache_no_pr_branch=""
    local -a gh_repo_args
    gh_repo_args=()
    branch="$(_hmux_git_branch_for_path "$repo_path" 2>/dev/null || true)"
    if [[ -z "$branch" ]] || ! command -v gh >/dev/null 2>&1; then
        _hmux_pr_debug_log "$branch" "cache-miss:clear"
        _hmux_pr_cache_clear
        _hmux_clear_pr_for_panel
        return 0
    fi

    prefix="$(_hmux_pr_cache_prefix 2>/dev/null || true)"
    if [[ -n "$prefix" ]]; then
        branch_file="${prefix}.branch"
        repo_file="${prefix}.repo"
        result_file="${prefix}.result"
        timestamp_file="${prefix}.timestamp"
        no_pr_branch_file="${prefix}.no-pr-branch"
        [[ -r "$branch_file" ]] && cache_branch="$(<"$branch_file")"
        [[ -r "$result_file" ]] && cache_result="$(<"$result_file")"
        [[ -r "$no_pr_branch_file" ]] && cache_no_pr_branch="$(<"$no_pr_branch_file")"
    fi

    _HMUX_PR_LAST_BRANCH="$cache_branch"
    _HMUX_PR_NO_PR_BRANCH="$cache_no_pr_branch"
    if [[ "$cache_branch" == "$branch" && -n "$cache_result" ]]; then
        _hmux_pr_debug_log "$branch" "cache-refresh"
    else
        _hmux_pr_debug_log "$branch" "cache-miss"
    fi

    repo_slug="$(_hmux_github_repo_slug_for_path "$repo_path")"
    if [[ -n "$repo_slug" ]]; then
        gh_repo_args=(--repo "$repo_slug")
    fi

    err_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/hmux-gh-pr-view.XXXXXX" 2>/dev/null || true)"
    [[ -n "$err_file" ]] || return 1
    gh_output="$(
        builtin cd -q "$repo_path" 2>/dev/null \
            && gh pr view "$branch" \
                "${gh_repo_args[@]}" \
                --json number,state,url \
                --jq '[.number, .state, .url] | @tsv' \
                2>|"$err_file"
    )"
    gh_status=$?
    if [[ -f "$err_file" ]]; then
        gh_error="$("/bin/cat" -- "$err_file" 2>/dev/null || true)"
        /bin/rm -f -- "$err_file" >/dev/null 2>&1 || true
    fi

    if (( gh_status != 0 )) || [[ -z "$gh_output" ]]; then
        if (( gh_status == 0 )) && [[ -z "$gh_output" ]]; then
            if [[ -n "$prefix" ]]; then
                print -r -- "$branch" >| "$branch_file"
                print -r -- "$repo_path" >| "$repo_file"
                print -r -- "$now" >| "$timestamp_file"
                print -r -- "none" >| "$result_file"
                print -r -- "$branch" >| "$no_pr_branch_file"
            fi
            _HMUX_PR_LAST_BRANCH="$branch"
            _HMUX_PR_NO_PR_BRANCH="$branch"
            _hmux_clear_pr_for_panel
            return 0
        fi
        if _hmux_pr_output_indicates_no_pull_request "$gh_error"; then
            if [[ -n "$prefix" ]]; then
                print -r -- "$branch" >| "$branch_file"
                print -r -- "$repo_path" >| "$repo_file"
                print -r -- "$now" >| "$timestamp_file"
                print -r -- "none" >| "$result_file"
                print -r -- "$branch" >| "$no_pr_branch_file"
            fi
            _HMUX_PR_LAST_BRANCH="$branch"
            _HMUX_PR_NO_PR_BRANCH="$branch"
            _hmux_clear_pr_for_panel
            return 0
        fi

        # Always scope PR detection to the exact current branch. When gh fails
        # transiently (auth hiccups, API lag, rate limiting), keep the last-known
        # badge and retry on the next poll instead of showing a mismatched PR.
        return 1
    fi

    local IFS=$'\t'
    read -r number state url <<< "$gh_output"
    if [[ -z "$number" ]] || [[ -z "$url" ]]; then
        return 1
    fi

    case "$state" in
        MERGED) status_opt="--state=merged" ;;
        OPEN) status_opt="--state=open" ;;
        CLOSED) status_opt="--state=closed" ;;
        *) return 1 ;;
    esac

    if [[ -n "$prefix" ]]; then
        print -r -- "$branch" >| "$branch_file"
        print -r -- "$repo_path" >| "$repo_file"
        print -r -- "$now" >| "$timestamp_file"
        printf '%s\t%s\t%s\t%s\n' "pr" "$number" "$state" "$url" >| "$result_file"
        /bin/rm -f -- "$no_pr_branch_file" >/dev/null 2>&1 || true
    fi
    _HMUX_PR_LAST_BRANCH="$branch"
    _HMUX_PR_NO_PR_BRANCH=""

    local quoted_branch="${branch//\"/\\\"}"
    _hmux_send "report_pr $number $url $status_opt --branch=\"$quoted_branch\" --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID"
}

_hmux_child_pids() {
    local parent_pid="$1"
    [[ -n "$parent_pid" ]] || return 0
    /bin/ps -ax -o pid= -o ppid= 2>/dev/null | /usr/bin/awk -v parent="$parent_pid" '$2 == parent { print $1 }'
}

_hmux_kill_process_tree() {
    local pid="$1"
    local signal="${2:-TERM}"
    local child_pid=""
    [[ -n "$pid" ]] || return 0

    while IFS= read -r child_pid; do
        [[ -n "$child_pid" ]] || continue
        [[ "$child_pid" == "$pid" ]] && continue
        _hmux_kill_process_tree "$child_pid" "$signal"
    done < <(_hmux_child_pids "$pid")

    kill "-$signal" "$pid" >/dev/null 2>&1 || true
}

_hmux_run_pr_probe_with_timeout() {
    local repo_path="$1"
    local force_probe="${2:-0}"
    local probe_pid=""
    local started_at="${EPOCHSECONDS:-$SECONDS}"
    local now=$started_at

    _hmux_zsh_job_table_saturated && return 1

    (
        _hmux_report_pr_for_path "$repo_path" "$force_probe"
    ) &
    probe_pid=$!

    while kill -0 "$probe_pid" >/dev/null 2>&1; do
        _hmux_sleep_cs 100
        now="${EPOCHSECONDS:-$SECONDS}"
        if (( _HMUX_ASYNC_JOB_TIMEOUT > 0 )) && (( now - started_at >= _HMUX_ASYNC_JOB_TIMEOUT )); then
            _hmux_kill_process_tree "$probe_pid" TERM
            _hmux_sleep_cs 20
            if kill -0 "$probe_pid" >/dev/null 2>&1; then
                _hmux_kill_process_tree "$probe_pid" KILL
                _hmux_sleep_cs 20
            fi
            if ! kill -0 "$probe_pid" >/dev/null 2>&1; then
                wait "$probe_pid" >/dev/null 2>&1 || true
            fi
            return 1
        fi
    done

    wait "$probe_pid"
}

# Stable parent identity for disowned watchers (issue #10926): a bare
# `kill -0 $pid` guard is defeated by PID reuse. macOS recycles PIDs within
# days on a busy machine, so once the recorded shell PID is reassigned to any
# live process the guard returns true forever and the watcher never exits
# (793 orphans / 2.1 GB after 20 days). Pair the PID with Darwin's kernel
# start time (epoch seconds) from Darwin so a recycled PID no longer counts as
# the parent. Both providers return the same representation.
_hmux_watcher_parent_start_time() {
    local pid="${1:-}" raw month day clock year token
    case "$pid" in ''|*[!0-9]*) return 1 ;; esac
    case "$pid" in *[1-9]*) ;; *) return 1 ;; esac
    local kernel="$(/usr/sbin/sysctl -n "kern.proc.pid.$pid" 2>/dev/null | /usr/bin/od -An -tu4 2>/dev/null)"
    local -a fields=(${=kernel})
    local i sec usec
    for (( i = 1; i < ${#fields}; i++ )); do
        sec="${fields[i]}"; usec="${fields[i+1]}"
        if [[ "$sec" == <-> && "$usec" == <-> ]] && (( sec >= 1000000000 && sec <= 3000000000 && usec < 1000000 )); then
            token="$sec"
            _hmux_watcher_parent_identity_valid "$pid" "$token" || return 1
            print -r -- "$token"
            return 0
        fi
    done
    # Darwin's ps exposes process start time through `lstart`, which is a
    # locale-formatted string. Force the stable C locale and UTC timezone,
    # then use date(1) to convert it to the same epoch-second token.
    raw="$(TZ=UTC LC_ALL=C /bin/ps -o lstart= -p "$pid" 2>/dev/null)" || return 1
    case "$raw" in *$'\n'*) return 1 ;; esac
    local -a words
    words=("${(@z)raw}")
    (( ${#words} == 5 )) || return 1
    case "${words[1]}" in Mon|Tue|Wed|Thu|Fri|Sat|Sun) ;; *) return 1 ;; esac
    case "${words[2]}" in
        Jan) month=01 ;; Feb) month=02 ;; Mar) month=03 ;;
        Apr) month=04 ;; May) month=05 ;; Jun) month=06 ;;
        Jul) month=07 ;; Aug) month=08 ;; Sep) month=09 ;;
        Oct) month=10 ;; Nov) month=11 ;; Dec) month=12 ;;
        *) return 1 ;;
    esac
    case "${words[3]}" in
        [1-9]) day="0${words[3]}" ;;
        0[1-9]|[12][0-9]|3[01]) day="${words[3]}" ;;
        *) return 1 ;;
    esac
    case "${words[4]}" in
        [01][0-9]:[0-5][0-9]:[0-5][0-9]|2[0-3]:[0-5][0-9]:[0-5][0-9]) clock="${words[4]}" ;;
        *) return 1 ;;
    esac
    case "${words[5]}" in
        [0-9][0-9][0-9][0-9]) year="${words[5]}" ;;
        *) return 1 ;;
    esac
    token="$(TZ=UTC LC_ALL=C /bin/date -j -u -f '%a %b %d %T %Y' "$raw" '+%s' 2>/dev/null)" || return 1
    [[ "$token" == <-> ]] || return 1
    _hmux_watcher_parent_identity_valid "$pid" "$token" || return 1
    print -r -- "$token"
}

_hmux_watcher_parent_identity_valid() {
    local pid="${1:-}" identity="${2:-}"
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    case "$pid" in
        *[1-9]*) ;;
        *) return 1 ;;
    esac
    case "$identity" in
        ''|*[!0-9]*) return 1 ;;
    esac
    (( ${#identity} >= 10 && ${#identity} <= 11 ))
}

_hmux_watcher_parent_state_valid() {
    local pid="${1:-}" state
    state="$(LC_ALL=C /bin/ps -o state= -p "$pid" 2>/dev/null)" || return 1
    state="${state#"${state%%[![:space:]]*}"}"
    state="${state%%[[:space:]]*}"
    case "$state" in
        ''|Z*) return 1 ;;
        *) return 0 ;;
    esac
}

_hmux_watcher_parent_alive() {
    # $1 = parent PID, $2 = numeric start time recorded at watcher spawn. A
    # mismatch means the PID was recycled; a failed /bin/ps counts as
    # parent-dead. Missing or malformed identity is also parent-dead, so a
    # watcher never falls back to PID-only liveness.
    local pid="${1:-}" expected="${2:-}" actual
    _hmux_watcher_parent_identity_valid "$pid" "$expected" || return 1
    kill -0 "$pid" >/dev/null 2>&1 || return 1
    _hmux_watcher_parent_state_valid "$pid" || return 1
    actual="$(_hmux_watcher_parent_start_time "$pid")" || return 1
    [[ "$actual" == "$expected" ]]
}

_hmux_capture_shell_start_time() {
    # Cache this shell's own start time once per shell lifetime: $$ never
    # changes, so the value cannot go stale, and watcher starts (one runs from
    # preexec) must not pay a /bin/ps fork per command. Only a valid value tied
    # to this shell PID is cached, so a transient ps failure heals on the next
    # watcher start.
    if [[ "${_HMUX_SHELL_START_PID:-}" == "$$" ]] \
        && _hmux_watcher_parent_identity_valid "$$" "${_HMUX_SHELL_START_TIME:-}"; then
        return 0
    fi
    typeset -g _HMUX_SHELL_START_PID _HMUX_SHELL_START_TIME
    _HMUX_SHELL_START_TIME=""
    _HMUX_SHELL_START_PID=""
    _HMUX_SHELL_START_TIME="$(_hmux_watcher_parent_start_time "$$" 2>/dev/null)" || return 1
    _hmux_watcher_parent_identity_valid "$$" "$_HMUX_SHELL_START_TIME" || {
        _HMUX_SHELL_START_TIME=""
        return 1
    }
    _HMUX_SHELL_START_PID="$$"
}

_hmux_watcher_guard_tick() {
    # Tiered per-iteration guard for watcher loops: the builtin kill -0 runs
    # every call (plain parent death is caught within one iteration), and the
    # /bin/ps identity comparison runs only every Nth call (default 30, via
    # _HMUX_WATCHER_IDENTITY_INTERVAL) so steady-state watchers do not fork
    # once per second. PID-reuse detection latency is bounded by N iterations.
    # Runs inside the forked watcher, so the countdown global is private to
    # that watcher.
    local pid="${1:-}" expected="${2:-}"
    _hmux_watcher_parent_identity_valid "$pid" "$expected" || return 1
    kill -0 "$pid" >/dev/null 2>&1 || return 1
    local countdown="${_HMUX_WATCHER_GUARD_COUNTDOWN:-0}"
    case "$countdown" in
        ''|*[!0-9]*) countdown=0 ;;
    esac
    if (( countdown > 0 )); then
        _HMUX_WATCHER_GUARD_COUNTDOWN=$(( countdown - 1 ))
        return 0
    fi
    local interval="${_HMUX_WATCHER_IDENTITY_INTERVAL:-30}"
    case "$interval" in
        ''|*[!0-9]*) interval=30 ;;
    esac
    (( interval > 0 )) || interval=30
    _HMUX_WATCHER_GUARD_COUNTDOWN=$(( interval - 1 ))
    _hmux_watcher_parent_alive "$pid" "$expected"
}

_hmux_halt_pr_poll_loop() {
    # Process-group kill: background jobs are process-group leaders, so
    # negative PID kills the loop + all descendants (gh, sleep) without
    # the synchronous /bin/ps + awk of tree-kill (~5-13ms).
    [[ -z "$_HMUX_PR_POLL_PID" ]] || kill -KILL -- -"$_HMUX_PR_POLL_PID" 2>/dev/null || true
    local signal_path="" REPLY
    [[ -n "$HMUX_PANEL_ID" ]] && _hmux_pr_state_dir && signal_path="$REPLY/force-${HMUX_PANEL_ID}"
    # preexec runs this before every command; only spawn rm when there is a file.
    [[ -n "$signal_path" && -e "$signal_path" ]] && { /bin/rm -f -- "$signal_path" >/dev/null 2>&1 || true; }
    _HMUX_PR_POLL_PID=""
    _HMUX_PR_POLL_PWD=""
}

_hmux_stop_pr_poll_loop() {
    _hmux_halt_pr_poll_loop
    _hmux_pr_cache_clear
}

_hmux_start_pr_poll_loop() {
    if [[ "${HMUX_NO_PR_WATCH:-}" == "1" ]]; then
        _hmux_stop_pr_poll_loop
        return 0
    fi
    [[ "${HMUX_NO_GIT_WATCH:-}" == "1" ]] && return 0
    [[ -S "$HMUX_SOCKET_PATH" ]] || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    [[ -n "$HMUX_PANEL_ID" ]] || return 0
    _hmux_zsh_job_table_saturated && return 0

    local watch_pwd="${1:-$PWD}"
    local force_restart="${2:-0}"
    local watch_shell_pid="$$"
    _hmux_capture_shell_start_time || return 0
    local watch_shell_start="$_HMUX_SHELL_START_TIME"
    local interval="${_HMUX_PR_POLL_INTERVAL:-45}"

    if [[ "$force_restart" != "1" && "$watch_pwd" == "$_HMUX_PR_POLL_PWD" && -n "$_HMUX_PR_POLL_PID" ]] \
        && kill -0 "$_HMUX_PR_POLL_PID" 2>/dev/null; then
        return 0
    fi

    if [[ -n "$_HMUX_PR_POLL_PID" ]] && kill -0 "$_HMUX_PR_POLL_PID" 2>/dev/null; then
        _hmux_halt_pr_poll_loop
    else
        _HMUX_PR_POLL_PID=""
    fi
    _HMUX_PR_POLL_PWD="$watch_pwd"

    {
        local signal_path=""
        signal_path="$(_hmux_pr_force_signal_path 2>/dev/null || true)"
        _HMUX_WATCHER_GUARD_COUNTDOWN=0
        while true; do
            _hmux_watcher_guard_tick "$watch_shell_pid" "$watch_shell_start" || break
            local force_probe=0
            if [[ -n "$signal_path" && -f "$signal_path" ]]; then
                force_probe=1
                /bin/rm -f -- "$signal_path" >/dev/null 2>&1 || true
            fi
            _hmux_run_pr_probe_with_timeout "$watch_pwd" "$force_probe" || true

            local slept=0
            while (( slept < interval )); do
                _hmux_watcher_guard_tick "$watch_shell_pid" "$watch_shell_start" || exit 0
                if [[ -n "$signal_path" && -f "$signal_path" ]]; then
                    break
                fi
                _hmux_sleep_cs 100
                slept=$(( slept + 1 ))
            done
        done
    } >/dev/null 2>&1 &!
    _HMUX_PR_POLL_PID=$!
}

_hmux_stop_git_head_watch() {
    [[ -n "$_HMUX_GIT_HEAD_WATCH_PID" ]] || return 0
    kill "$_HMUX_GIT_HEAD_WATCH_PID" >/dev/null 2>&1 || true
    _HMUX_GIT_HEAD_WATCH_PID=""
}

_hmux_start_git_head_watch() {
    [[ "${HMUX_NO_GIT_WATCH:-}" == "1" ]] && return 0
    [[ -S "$HMUX_SOCKET_PATH" ]] || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    [[ -n "$HMUX_PANEL_ID" ]] || return 0
    _hmux_zsh_job_table_saturated && return 0

    local watch_pwd="$PWD"
    local watch_head_path
    watch_head_path="$(_hmux_git_resolve_head_path "$watch_pwd" 2>/dev/null || true)"
    [[ -n "$watch_head_path" ]] || return 0

    local REPLY watch_head_signature
    _hmux_git_head_signature_into_reply "$watch_head_path" 2>/dev/null || true
    watch_head_signature="$REPLY"

    _HMUX_GIT_HEAD_LAST_PWD="$watch_pwd"
    _HMUX_GIT_HEAD_PATH="$watch_head_path"
    _HMUX_GIT_HEAD_SIGNATURE="$watch_head_signature"

    _hmux_stop_git_head_watch
    local watch_shell_pid="$$"
    _hmux_capture_shell_start_time || return 0
    local watch_shell_start="$_HMUX_SHELL_START_TIME"
    {
        local last_signature="$watch_head_signature"
        _HMUX_WATCHER_GUARD_COUNTDOWN=0
        while true; do
            _hmux_watcher_guard_tick "$watch_shell_pid" "$watch_shell_start" || break
            _hmux_sleep_cs 100

            local signature
            _hmux_git_head_signature_into_reply "$watch_head_path" 2>/dev/null || true
            signature="$REPLY"
            if [[ -n "$signature" && "$signature" != "$last_signature" ]]; then
                last_signature="$signature"
                _hmux_pr_cache_clear
                _hmux_report_git_branch_for_path "$watch_pwd"
                _hmux_clear_pr_for_panel
            fi
        done
    } >/dev/null 2>&1 &!
    _HMUX_GIT_HEAD_WATCH_PID=$!
}

_hmux_command_starts_nested_shell() {
    local cmd="$1"
    local -a words
    words=("${(z)cmd}")

    local index=1
    local word base
    while (( index <= ${#words} )); do
        word="${words[index]}"

        case "$word" in
            *=*)
                index=$(( index + 1 ))
                continue ;;
            exec|command|builtin|noglob|time)
                index=$(( index + 1 ))
                continue ;;
            env)
                index=$(( index + 1 ))
                while (( index <= ${#words} )); do
                    word="${words[index]}"
                    case "$word" in
                        -*|*=*)
                            index=$(( index + 1 ))
                            continue ;;
                    esac
                    break
                done
                continue ;;
        esac

        base="${word:t}"
        case "$base" in
            bash|zsh|sh|fish|nu|nix-shell)
                return 0 ;;
            nix)
                local next_index=$(( index + 1 ))
                local next_word="${words[next_index]}"
                case "$next_word" in
                    develop|shell)
                        return 0 ;;
                esac ;;
        esac

        return 1
    done

    return 1
}

# True when a command line runs Claude Code. Claude reports its own cwd through
# hooks while it runs (`claude --worktree` moves it to another checkout), so the
# next prompt must re-report $PWD even though the shell never left it. Extra
# matches only cost one redundant report_pwd.
_hmux_command_runs_claude() {
    [[ "$1" == *claude* ]] || return 1
    local word
    for word in ${(z)1}; do
        case "${word:t}" in
            claude|hmux-claude-wrapper) return 0 ;;
        esac
    done
    return 1
}

_hmux_preexec() {
    local cmd="${1## }"
    # $3 is the alias-expanded command line.
    if _hmux_command_runs_claude "$cmd" || _hmux_command_runs_claude "${3:-}"; then
        _HMUX_PWD_LAST_PWD=""
    fi
    _hmux_halt_pr_poll_loop
    _hmux_stop_git_head_watch
    _hmux_zsh_job_table_saturated && return 0

    _hmux_normalize_claude_config_dir
    if (( ! _HMUX_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT )); then
        _hmux_restore_terminal_identity_after_startup
    fi
    _hmux_tmux_sync_hmux_environment

    if [[ -z "$_HMUX_TTY_NAME" ]]; then
        # zsh already knows its terminal in $TTY; only spawn tty(1) without it.
        local t="${TTY:-}"
        [[ -n "$t" ]] || t="$(tty 2>/dev/null || true)"
        t="${t##*/}"
        [[ -n "$t" && "$t" != "not a tty" ]] && _HMUX_TTY_NAME="$t"
    fi

    _HMUX_CMD_START="${EPOCHSECONDS:-$SECONDS}"
    _hmux_report_shell_activity_state running
    _hmux_record_pr_command_hint "$cmd"

    # Heuristic: commands that may change git branch/dirty state without changing $PWD.
    case "$cmd" in
        git\ *|git|gh\ *|lazygit|lazygit\ *|tig|tig\ *|gitui|gitui\ *|stg\ *|jj\ *)
            _HMUX_GIT_FORCE=1
            _HMUX_PR_FORCE=1 ;;
    esac

    # Register TTY + kick batched port scan for foreground commands (servers).
    _hmux_report_tty_once
    _hmux_ports_kick command
    if _hmux_command_starts_nested_shell "$cmd"; then
        return 0
    fi
    _hmux_start_git_head_watch
}

# Per-terminal history, layered on the shell's own. HISTFILE is left alone,
# so a new terminal recalls global history and every command still reaches
# the global file exactly as in any other terminal. Alongside it, each
# command is appended to this surface's file; when a restored terminal finds
# entries there, they are read on top of global history so Up recalls what
# was typed in this terminal first. With SAVEHIST unset or zero zsh persists
# nothing, and neither does this.
_hmux_terminal_history_precmd() {
    [[ -n "${HMUX_HISTORY_FILE:-}" && -n "${HISTFILE:-}" && "$HISTFILE" != /dev/null ]] || return 0
    (( ${SAVEHIST:-0} > 0 )) || return 0
    local entry
    if [[ -z "${_HMUX_HISTORY_INITIALIZED:-}" ]]; then
        typeset -g _HMUX_HISTORY_INITIALIZED=1
        if [[ -s "$HMUX_HISTORY_FILE" ]]; then
            local -a lines
            lines=("${(@f)$(<"$HMUX_HISTORY_FILE")}")
            if (( ${#lines} > SAVEHIST )); then
                print -rl -- "${(@)lines[-SAVEHIST,-1]}" >| "$HMUX_HISTORY_FILE"
            fi
            builtin fc -R "$HMUX_HISTORY_FILE"
        fi
        # Anything already in the list came from a file, not from this
        # terminal's prompt; start recording after it.
        entry="$(builtin fc -l -1 2>/dev/null)"
        [[ "$entry" =~ '^ *([0-9]+)' ]] && typeset -g _HMUX_HISTORY_LAST="$match[1]"
        return 0
    fi
    entry="$(builtin fc -l -1 2>/dev/null)"
    [[ "$entry" =~ '^ *([0-9]+)\*? +(.*)$' ]] || return 0
    [[ "$match[1]" != "${_HMUX_HISTORY_LAST:-}" ]] || return 0
    typeset -g _HMUX_HISTORY_LAST="$match[1]"
    # hist_ignore_space leaves the last such line in the list until the next
    # command; it was never meant to be kept, so it is not recorded either.
    local line="$(builtin fc -ln -1 2>/dev/null)"
    [[ -o hist_ignore_space && "$line" == ' '* ]] && return 0
    # `>>|` appends even under noclobber, which refuses to create the file
    # with a plain `>>` and prints an error after every command (#26514).
    print -r -- "$line" >>| "$HMUX_HISTORY_FILE"
}

_hmux_precmd() {
    local last_status=$?
    _hmux_terminal_history_precmd
    # Ghostty integration can initialize after this file, so retry its job-table
    # guards when each prompt begins.
    _hmux_patch_ghostty_job_table_guard
    _hmux_stop_git_head_watch
    _hmux_zsh_job_table_saturated && return 0

    _hmux_normalize_claude_config_dir
    if (( _HMUX_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT )); then
        _HMUX_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=0
    fi
    _hmux_tmux_sync_hmux_environment

    local hmux_has_unix_socket=0
    _hmux_socket_is_unix && hmux_has_unix_socket=1
    (( hmux_has_unix_socket )) || _hmux_has_port_scan_transport || return 0
    [[ -n "$HMUX_TAB_ID" ]] || return 0
    if [[ -n "$HMUX_PANEL_ID" ]]; then
        _hmux_reset_terminal_leftover_modes
        _hmux_reset_terminal_keyboard_protocols
    fi
    if [[ -n "$HMUX_PANEL_ID" ]] || (( ! hmux_has_unix_socket )); then
        _hmux_report_shell_activity_state prompt
    fi

    if [[ -z "$_HMUX_TTY_NAME" ]]; then
        # zsh already knows its terminal in $TTY; only spawn tty(1) without it.
        local t="${TTY:-}"
        [[ -n "$t" ]] || t="$(tty 2>/dev/null || true)"
        t="${t##*/}"
        [[ -n "$t" && "$t" != "not a tty" ]] && _HMUX_TTY_NAME="$t"
    fi

    _hmux_report_tty_once

    local now="${EPOCHSECONDS:-$SECONDS}"
    local cmd_start="$_HMUX_CMD_START"
    _HMUX_CMD_START=0
    local pwd="$PWD"
    local cmd_dur=0
    if [[ -n "$cmd_start" && "$cmd_start" != 0 ]]; then
        cmd_dur=$(( now - cmd_start ))
    fi

    if (( ! hmux_has_unix_socket )); then
        if [[ "$pwd" != "$_HMUX_PWD_LAST_PWD" ]]; then
            _hmux_report_pwd_via_relay "$pwd" && _HMUX_PWD_LAST_PWD="$pwd"
        fi
    else
        [[ -n "$HMUX_PANEL_ID" ]] || return 0
    fi

    _hmux_set_git_active_pwd "$pwd" create

    # Post-wake socket writes can occasionally leave a probe process wedged.
    # If one probe is stale, clear the guard so fresh async probes can resume.
    if [[ -n "$_HMUX_GIT_JOB_PID" ]]; then
        if ! kill -0 "$_HMUX_GIT_JOB_PID" 2>/dev/null; then
            _HMUX_GIT_JOB_PID=""
            _HMUX_GIT_JOB_STARTED_AT=0
        elif (( _HMUX_GIT_JOB_STARTED_AT > 0 )) && (( now - _HMUX_GIT_JOB_STARTED_AT >= _HMUX_ASYNC_JOB_TIMEOUT )); then
            _HMUX_GIT_JOB_PID=""
            _HMUX_GIT_JOB_STARTED_AT=0
            _HMUX_GIT_FORCE=1
        fi
    fi

    # CWD: keep the app in sync with the actual shell directory.
    # This is also the simplest way to test sidebar directory behavior end-to-end.
    if (( hmux_has_unix_socket )) && [[ "$pwd" != "$_HMUX_PWD_LAST_PWD" ]]; then
        _HMUX_PWD_LAST_PWD="$pwd"
        local qpwd="${pwd//\"/\\\"}"
        _hmux_send_bg "report_pwd \"${qpwd}\" --tab=$HMUX_TAB_ID --panel=$HMUX_PANEL_ID"
    fi

    # Git branch/dirty: update immediately on directory change, otherwise every ~3s.
    # While a foreground command is running, _hmux_start_git_head_watch probes HEAD
    # once per second so agent-initiated git checkouts still surface quickly.
    local should_git=0
    local git_head_changed=0

    # Git branch can change without a `git ...`-prefixed command (aliases like `gco`,
    # tools like `gh pr checkout`, etc.). Detect HEAD changes and force a refresh.
    if [[ "${HMUX_NO_GIT_WATCH:-}" == "1" ]]; then
        _hmux_stop_pr_poll_loop
        _hmux_stop_git_head_watch
        if [[ -n "$_HMUX_GIT_JOB_PID" ]] && kill -0 "$_HMUX_GIT_JOB_PID" 2>/dev/null; then
            kill "$_HMUX_GIT_JOB_PID" >/dev/null 2>&1 || true
        fi
        _HMUX_GIT_JOB_PID=""
        _HMUX_GIT_JOB_STARTED_AT=0
        _HMUX_GIT_FORCE=0
        _HMUX_GIT_HEAD_LAST_PWD=""
        _HMUX_GIT_HEAD_PATH=""
        _HMUX_GIT_HEAD_SIGNATURE=""
        _HMUX_GIT_LAST_PWD=""
        _HMUX_PR_FORCE=0
        _HMUX_LAST_PR_ACTION=""
        _HMUX_LAST_PR_TARGET=""
    else
        if [[ "$pwd" != "$_HMUX_GIT_HEAD_LAST_PWD" ]]; then
            _HMUX_GIT_HEAD_LAST_PWD="$pwd"
            local REPLY
            _hmux_git_resolve_head_path_into_reply "$pwd" 2>/dev/null || true
            _HMUX_GIT_HEAD_PATH="$REPLY"
            _HMUX_GIT_HEAD_SIGNATURE=""
        fi
        if [[ -n "$_HMUX_GIT_HEAD_PATH" ]]; then
            # Read HEAD in place; a command substitution here forked every prompt.
            local head_signature=""
            if [[ -r "$_HMUX_GIT_HEAD_PATH" ]]; then
                IFS= read -r head_signature < "$_HMUX_GIT_HEAD_PATH" 2>/dev/null || head_signature=""
            fi
            if [[ -n "$head_signature" ]]; then
                if [[ -z "$_HMUX_GIT_HEAD_SIGNATURE" ]]; then
                    # The first observed HEAD value establishes the baseline for this
                    # shell session. Don't treat it as a branch change or we'll clear
                    # restore-seeded PR badges before the first background probe runs.
                    _HMUX_GIT_HEAD_SIGNATURE="$head_signature"
                elif [[ "$head_signature" != "$_HMUX_GIT_HEAD_SIGNATURE" ]]; then
                    _HMUX_GIT_HEAD_SIGNATURE="$head_signature"
                    git_head_changed=1
                    # Treat HEAD file change like a git command — force-replace any
                    # running probe so the sidebar picks up the new branch immediately.
                    _HMUX_GIT_FORCE=1
                    _HMUX_PR_FORCE=1
                    should_git=1
                fi
            fi
        fi
    fi

    if [[ "$pwd" != "$_HMUX_GIT_LAST_PWD" ]]; then
        should_git=1
    elif (( _HMUX_GIT_FORCE )); then
        should_git=1
    elif (( now - _HMUX_GIT_LAST_RUN >= 3 )); then
        should_git=1
    fi

    if [[ "${HMUX_NO_GIT_WATCH:-}" != "1" ]] && (( should_git )); then
        local can_launch_git=1
        if [[ -n "$_HMUX_GIT_JOB_PID" ]] && kill -0 "$_HMUX_GIT_JOB_PID" 2>/dev/null; then
            # If a stale probe is still running but the cwd changed (or we just ran
            # a git command), restart immediately so branch state isn't delayed
            # until the next user command/prompt.
            # Note: this repeats the cwd check above on purpose. The first check
            # decides whether we should refresh at all; this one decides whether
            # an in-flight older probe can be reused vs. replaced.
            if [[ "$pwd" != "$_HMUX_GIT_LAST_PWD" ]] || (( _HMUX_GIT_FORCE )); then
                kill "$_HMUX_GIT_JOB_PID" >/dev/null 2>&1 || true
                _HMUX_GIT_JOB_PID=""
                _HMUX_GIT_JOB_STARTED_AT=0
            else
                can_launch_git=0
            fi
        fi

        if (( can_launch_git )); then
            _HMUX_GIT_FORCE=0
            _HMUX_GIT_LAST_PWD="$pwd"
            _HMUX_GIT_LAST_RUN=$now
            {
                _hmux_report_git_branch_for_path "$pwd"
            } >/dev/null 2>&1 &!
            _HMUX_GIT_JOB_PID=$!
            _HMUX_GIT_JOB_STARTED_AT=$now
        fi
    fi
    if (( hmux_has_unix_socket )); then
        if (( git_head_changed )); then
            _hmux_pr_cache_clear
            _hmux_clear_pr_for_panel
        fi
        if [[ "${HMUX_NO_GIT_WATCH:-}" != "1" ]] && (( last_status == 0 )); then
            _hmux_emit_pr_command_hint
        else
            _HMUX_LAST_PR_ACTION=""
            _HMUX_LAST_PR_TARGET=""
        fi
    fi

    # Ports: lightweight kick to the app's batched scanner.
    # - Periodic scan to avoid stale values.
    # - Forced scan when a long-running command returns to the prompt (common when stopping a server).
    if (( cmd_dur >= 2 || now - _HMUX_PORTS_LAST_RUN >= 10 )); then
        _hmux_ports_kick refresh
    fi
}

# Ensure Resources/bin is at the front of PATH, and remove the app's
# Contents/MacOS entry so the GUI hmux binary cannot shadow the CLI hmux.
# Shell init (.zprofile/.zshrc) may prepend other dirs after launch.
# We fix this once on first prompt (after all init files have run), and
# reinstall hmux-owned wrapper functions in case user startup replaced them.
_hmux_fix_path() {
    local integration_dir="${HMUX_SHELL_INTEGRATION_DIR:-}"
    integration_dir="${integration_dir%/}"
    if [[ "$integration_dir" == */Resources/shell-integration ]]; then
        local resources_dir="${integration_dir%/shell-integration}"
        local gui_dir="${resources_dir%/Resources}/MacOS"
        local bin_dir="$resources_dir/bin"
        if [[ -d "$bin_dir" ]]; then
            local REPLY
            _hmux_path_prepend_unique_directory_into_reply "$bin_dir" "${PATH-}" "$gui_dir"
            PATH="$REPLY"
        fi
    fi
    _hmux_install_cli_wrapper claude _HMUX_CLAUDE_WRAPPER hmux-claude-wrapper
    _hmux_install_cli_wrapper grok _HMUX_GROK_WRAPPER
    _hmux_install_cli_wrapper muse _HMUX_MUSE_WRAPPER
    add-zsh-hook -d precmd _hmux_fix_path
}

_hmux_chpwd() {
    # Only refresh the active-cwd marker so async git reporters (the HEAD-watch
    # loop and deferred prompt probes) are scoped to the new cwd. Do NOT tear the
    # HEAD watch down here: chpwd fires mid-line for compound commands such as
    # `cd foo && pnpm dev`, and killing the watcher would drop live branch updates
    # during the long-running step. The marker guard already suppresses any stale
    # report for the path the shell just left, and precmd stops the watch at the
    # next prompt.
    _hmux_set_git_active_pwd "$PWD"
}

_hmux_restore_terminal_identity_after_startup() {
    if [[ -n "${HMUX_ZSH_RESTORE_TERM:-}" ]]; then
        builtin export TERM="$HMUX_ZSH_RESTORE_TERM"
        builtin unset HMUX_ZSH_RESTORE_TERM
    fi
    _HMUX_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=0
}

_hmux_zshexit() {
    _hmux_stop_git_head_watch
    _hmux_stop_pr_poll_loop
    [[ -n "${_HMUX_GIT_ACTIVE_PWD_FILE:-}" ]] && /bin/rm -f -- "$_HMUX_GIT_ACTIVE_PWD_FILE" >/dev/null 2>&1 || true
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _hmux_preexec
add-zsh-hook precmd _hmux_precmd
add-zsh-hook precmd _hmux_fix_path
add-zsh-hook chpwd _hmux_chpwd
add-zsh-hook zshexit _hmux_zshexit
