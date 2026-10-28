# hmux shell integration for nushell
# Sourced automatically by the hmux nushell bootstrap; do not source manually.
#
# Feature parity target is the fish integration
# (Resources/shell-integration/fish/config.fish): socket reporting of tty,
# shell activity state, pwd changes, and port-scan kicks, plus the claude/grok
# CLI wrappers, scrollback restore, and the keyboard-protocol reset. The
# zsh-only extras (git-branch probes, PR polling, Ghostty job-table patching)
# are intentionally not replicated here.
#
# State lives in _HMUX_* environment variables because nushell hook closures
# cannot mutate the environment; hmux registers string hooks that call the
# `def --env` entry points below, so mutations persist across prompts.

# Whether the hmux integration is active (HMUX_SHELL_INTEGRATION=0 disables it).
def _hmux_integration_enabled [] {
    ($env.HMUX_SHELL_INTEGRATION? | default "1") != "0"
}

# Picks the socket transport once at source time: ncat, socat, or nc.
def _hmux_pick_send_tool [] {
    if (which ncat | is-not-empty) {
        "ncat"
    } else if (which socat | is-not-empty) {
        "socat"
    } else if (which nc | is-not-empty) {
        "nc"
    } else {
        ""
    }
}

# Whether HMUX_SOCKET_PATH points at a live unix socket; positive results are
# cached for the session because the probe forks /bin/test.
def --env _hmux_socket_is_unix [] {
    let sock = ($env.HMUX_SOCKET_PATH? | default "")
    if ($sock | is-empty) { return false }
    if not ($sock | str starts-with "/") { return false }
    # The probe forks /bin/test and this runs from every prompt hook, so cache
    # the positive result for the session (the socket path is session-stable).
    # A negative result is not cached: the socket may come up moments later.
    if ($env._HMUX_SOCKET_IS_UNIX? | default "") == $"yes:($sock)" { return true }
    let live = ((^/bin/test -S $sock | complete | get exit_code) == 0)
    if $live { $env._HMUX_SOCKET_IS_UNIX = $"yes:($sock)" }
    $live
}

# Resolves the hmux CLI used for remote-relay RPCs, preferring the bundled binary.
def _hmux_relay_cli_path [] {
    let bundled = ($env.HMUX_BUNDLED_CLI_PATH? | default "")
    if ($bundled != "") and ($bundled | path exists) { return $bundled }
    which hmux | get -o 0.path | default ""
}

# Whether HMUX_SOCKET_PATH is a host:port relay address reachable through the hmux CLI.
def _hmux_socket_uses_remote_relay [] {
    let sock = ($env.HMUX_SOCKET_PATH? | default "")
    if ($sock | is-empty) { return false }
    if ($sock | str starts-with "/") { return false }
    if not ($sock | str contains ":") { return false }
    (_hmux_relay_cli_path) != ""
}

# Sends one payload line to the hmux socket, synchronously.
def _hmux_send [payload: string] {
    if ($payload | is-empty) { return }
    let sock = ($env.HMUX_SOCKET_PATH? | default "")
    if ($sock | is-empty) { return }
    let tool = ($env._HMUX_SEND_TOOL? | default "")
    let line = $"($payload)(char nl)"
    if $tool == "ncat" {
        $line | ^ncat -w 1 -U $sock --send-only | complete | ignore
    } else if $tool == "socat" {
        $line | ^socat -T 1 - $"UNIX-CONNECT:($sock)" | complete | ignore
    } else if $tool == "nc" {
        let first = ($line | ^nc -N -U $sock | complete)
        if $first.exit_code != 0 {
            $line | ^nc -w 1 -U $sock | complete | ignore
        }
    }
}

# Sends a payload without blocking the prompt (job spawn). HMUX_TEST_SYNC_SEND=1
# forces the synchronous path so tests are deterministic (nushell kills jobs at
# shell exit, which a -c script would race).
def _hmux_send_bg [payload: string] {
    if ($env.HMUX_TEST_SYNC_SEND? | default "") == "1" {
        _hmux_send $payload
        return
    }
    job spawn { _hmux_send $payload } | ignore
}

# Escapes a value for the quoted field of a socket payload, mirroring the fish
# integration's escaping so the app-side parser sees identical wire format.
def _hmux_json_escape [value: string] {
    $value
    | str replace -a "\\" "\\\\"
    | str replace -a '"' '\"'
    | str replace -a "\n" "\\n"
    | str replace -a "\r" "\\r"
    | str replace -a "\t" "\\t"
}

# Workspace id for relay RPC params, falling back to the tab id.
def _hmux_relay_workspace_id [] {
    let workspace = ($env.HMUX_WORKSPACE_ID? | default "")
    if $workspace != "" { return $workspace }
    $env.HMUX_TAB_ID? | default ""
}

# Fires a hmux relay RPC without blocking the prompt.
def _hmux_relay_rpc_bg [method: string, params: string] {
    let cli = (_hmux_relay_cli_path)
    if ($cli | is-empty) { return }
    if ($env.HMUX_TEST_SYNC_SEND? | default "") == "1" {
        ^$cli rpc $method $params | complete | ignore
        return
    }
    job spawn { ^$cli rpc $method $params | complete | ignore } | ignore
}

# Reports the tty name through the remote relay.
def _hmux_report_tty_via_relay [] {
    if not (_hmux_socket_uses_remote_relay) { return }
    let name = ($env._HMUX_TTY_NAME? | default "")
    if ($name | is-empty) { return }
    let workspace = (_hmux_relay_workspace_id)
    if ($workspace | is-empty) { return }
    mut payload = {workspace_id: $workspace, tty_name: $name}
    let panel = ($env.HMUX_PANEL_ID? | default "")
    if $panel != "" { $payload = ($payload | insert surface_id $panel) }
    _hmux_relay_rpc_bg surface.report_tty ($payload | to json --raw)
}

# Reports a cwd change through the remote relay; returns true when dispatched.
def _hmux_report_pwd_via_relay [pwd: string] {
    if not (_hmux_socket_uses_remote_relay) { return false }
    if ($pwd | is-empty) { return false }
    let workspace = (_hmux_relay_workspace_id)
    if ($workspace | is-empty) { return false }
    mut payload = {workspace_id: $workspace, path: $pwd}
    let panel = ($env.HMUX_PANEL_ID? | default "")
    if $panel != "" { $payload = ($payload | insert surface_id $panel) }
    _hmux_relay_rpc_bg surface.report_pwd ($payload | to json --raw)
    true
}

# Requests a port scan through the remote relay.
def _hmux_ports_kick_via_relay [reason: string] {
    if not (_hmux_socket_uses_remote_relay) { return }
    let workspace = (_hmux_relay_workspace_id)
    if ($workspace | is-empty) { return }
    mut payload = {workspace_id: $workspace, reason: $reason}
    let panel = ($env.HMUX_PANEL_ID? | default "")
    if $panel != "" { $payload = ($payload | insert surface_id $panel) }
    _hmux_relay_rpc_bg surface.ports_kick ($payload | to json --raw)
}

# Reports the surface tty once per session so hmux can map this shell to its
# panel. Honors a preset _HMUX_TTY_NAME (tests have no tty to probe).
def --env _hmux_report_tty_once [] {
    if ($env._HMUX_TTY_REPORTED? | default "") == "1" { return }
    mut name = ($env._HMUX_TTY_NAME? | default "")
    if ($name | is-empty) {
        let probe = (^tty | complete)
        if $probe.exit_code == 0 {
            $name = ($probe.stdout | str trim | str replace -r '^.*/' '')
        }
    }
    if ($name | is-empty) or ($name == "not a tty") { return }
    $env._HMUX_TTY_NAME = $name
    if (_hmux_socket_is_unix) {
        let tab = ($env.HMUX_TAB_ID? | default "")
        if ($tab | is-empty) { return }
        let panel = ($env.HMUX_PANEL_ID? | default "")
        if ($panel | is-empty) { return }
        $env._HMUX_TTY_REPORTED = "1"
        _hmux_send_bg $"report_tty ($name) --tab=($tab) --panel=($panel)"
    } else if (_hmux_socket_uses_remote_relay) {
        $env._HMUX_TTY_REPORTED = "1"
        _hmux_report_tty_via_relay
    }
}

# Reports busy/idle transitions (running/prompt), deduped across repeated prompts.
def --env _hmux_report_shell_activity_state [state: string] {
    if ($state | is-empty) { return }
    # Dedupe before the socket probe: this runs on every prompt and the
    # state is unchanged almost every time.
    if ($env._HMUX_SHELL_ACTIVITY_LAST? | default "") == $state { return }
    if not (_hmux_socket_is_unix) { return }
    let tab = ($env.HMUX_TAB_ID? | default "")
    if ($tab | is-empty) { return }
    let panel = ($env.HMUX_PANEL_ID? | default "")
    if ($panel | is-empty) { return }
    $env._HMUX_SHELL_ACTIVITY_LAST = $state
    _hmux_send_bg $"report_shell_state ($state) --tab=($tab) --panel=($panel)"
}

# Reports the cwd when it changed since the last prompt; feeds hmux's
# workspace current-directory tracking.
def --env _hmux_report_pwd_if_changed [] {
    let pwd = $env.PWD
    if $pwd == ($env._HMUX_PWD_LAST_PWD? | default "") { return }
    if (_hmux_socket_is_unix) {
        let tab = ($env.HMUX_TAB_ID? | default "")
        if ($tab | is-empty) { return }
        let panel = ($env.HMUX_PANEL_ID? | default "")
        if ($panel | is-empty) { return }
        let qpwd = (_hmux_json_escape $pwd)
        _hmux_send_bg $"report_pwd \"($qpwd)\" --tab=($tab) --panel=($panel)"
        $env._HMUX_PWD_LAST_PWD = $pwd
    } else if (_hmux_report_pwd_via_relay $pwd) {
        $env._HMUX_PWD_LAST_PWD = $pwd
    }
}

# Requests a hmux port scan (reason: command or refresh).
def --env _hmux_ports_kick [reason: string] {
    mut why = $reason
    if ($why | is-empty) { $why = "command" }
    let tab = ($env.HMUX_TAB_ID? | default "")
    if ($tab | is-empty) { return }
    $env._HMUX_PORTS_LAST_RUN = (date now | format date "%s")
    if (_hmux_socket_is_unix) {
        let panel = ($env.HMUX_PANEL_ID? | default "")
        if ($panel | is-empty) { return }
        _hmux_send_bg $"ports_kick --tab=($tab) --panel=($panel) --reason=($why)"
    } else {
        _hmux_ports_kick_via_relay $why
    }
}

# Resets the mouse reporting, focus reports, bracketed paste and alternate
# screen a killed TUI can leave on (reedline turns its own paste mode back on
# after this hook). ESC 7 keeps the cursor when no alternate screen is up;
# tmux and screen keep the 1049 cursor apart from ESC 7, so they skip it.
def _hmux_reset_terminal_leftover_modes [] {
    let forced = ($env.HMUX_TEST_FORCE_KEYBOARD_RESET? | default "")
    if ($forced | is-empty) and not (is-terminal --stdout) { return }
    print -n "\e[?9l\e[?1000l\e[?1002l\e[?1003l\e[?1005l\e[?1006l\e[?1015l\e[?1016l\e[?1004l\e[?2004l\e[?25h"
    let multiplexed = ($env.TMUX? | default "") + ($env.STY? | default "")
    if ($multiplexed | is-empty) { print -n "\e7\e[?1049l" }
}

# Resets modifyOtherKeys/kitty keyboard protocols a crashed TUI can leave enabled.
def _hmux_reset_terminal_keyboard_protocols [] {
    let forced = ($env.HMUX_TEST_FORCE_KEYBOARD_RESET? | default "") + ($env.HMUX_TEST_FORCE_KITTY_RESET? | default "")
    if ($forced | is-empty) and not (is-terminal --stdout) { return }
    print -n "\e[>m\e[<8u"
}

# Replays saved scrollback into a restored surface, bracketed by the OSC 1337
# markers hmux recognizes, then deletes the replay file.
def --env _hmux_restore_scrollback_once [] {
    let path = ($env.HMUX_RESTORE_SCROLLBACK_FILE? | default "")
    if ($path | is-empty) { return }
    hide-env HMUX_RESTORE_SCROLLBACK_FILE
    let token = ($path | str replace -r '^.*/' '')
    let host = (^/bin/hostname | complete | get stdout | str trim)
    print -n $"\e]1337;CurrentDir=kitty-shell-cwd://($host)/.hmux/session-scrollback-replay/($token)/start\u{07}"
    if ($path | path exists) {
        try { ^/bin/cat -- $path }
        ^/bin/rm -f -- $path | complete | ignore
    }
    print -n $"\e]1337;CurrentDir=kitty-shell-cwd://($host)/.hmux/session-scrollback-replay/($token)/end\u{07}"
    print -n $"\e]1337;CurrentDir=kitty-shell-cwd://($host)($env.PWD)\u{07}"
}

# First-launch welcome banner. hmux passes the path of a one-shot token file in
# HMUX_SHOW_WELCOME_FILE instead of typing `hmux welcome` into the first
# workspace's shell, so the banner prints during startup and never lands in
# shell history. Only the shell whose `rm` of the token succeeds prints it, and
# never inside tmux, so children that inherited the variable cannot repeat it.
def --env _hmux_show_welcome_once [] {
    let token = ($env.HMUX_SHOW_WELCOME_FILE? | default "")
    if ($token | is-empty) { return }
    hide-env HMUX_SHOW_WELCOME_FILE
    if (^/bin/rm -- $token | complete | get exit_code) != 0 { return }
    if not (($env.TMUX? | default "") | is-empty) { return }
    let cli = (_hmux_wrapper_path "hmux")
    if ($cli | is-empty) { return }
    try { ^$cli welcome }
}

# Locates a bundled hmux CLI wrapper relative to HMUX_SHELL_INTEGRATION_DIR.
def _hmux_wrapper_path [wrapper_file: string] {
    let dir = ($env.HMUX_SHELL_INTEGRATION_DIR? | default "")
    if ($dir | is-empty) { return "" }
    let bundle = ($dir | str replace -r '/shell-integration/?$' '')
    let candidate = ($bundle | path join "bin" $wrapper_file)
    if ($candidate | path exists) { $candidate } else { "" }
}

# Route `claude` through the hmux wrapper so session tracking and
# notification hooks are injected even if later PATH edits shadow the
# per-surface shim. `^claude` resolves the real external through PATH.
#
# The Automation toggle owns command interception. Nushell applies `hide` at
# parse time, even inside an `if` that never runs, so a conditional hide
# removed the wrapper for everyone. Decide at call time instead: with
# integration off, run the user's external `claude` directly.
def --wrapped claude [...args: string] {
    let shim = ($env.HMUX_CLAUDE_WRAPPER_SHIM? | default "")
    if ($env.HMUX_CLAUDE_INTEGRATION_DISABLED? | default "") == "1" {
        ^claude ...$args
    } else if ($shim != "") and ($shim | path exists) {
        ^$shim ...$args
    } else {
        let wrapper = (_hmux_wrapper_path "hmux-claude-wrapper")
        if ($wrapper != "") {
            ^$wrapper ...$args
        } else {
            ^claude ...$args
        }
    }
}

# Routes agy through the bundled hmux wrapper when present.
def --wrapped agy [...args: string] {
    let wrapper = (_hmux_wrapper_path "agy")
    if ($wrapper != "") {
        ^$wrapper ...$args
    } else {
        ^agy ...$args
    }
}

# Routes grok through the bundled hmux wrapper when present.
def --wrapped grok [...args: string] {
    let wrapper = (_hmux_wrapper_path "grok")
    if ($wrapper != "") {
        ^$wrapper ...$args
    } else {
        ^grok ...$args
    }
}

# Routes muse through the bundled hmux wrapper when present.
def --wrapped muse [...args: string] {
    let wrapper = (_hmux_wrapper_path "muse")
    if ($wrapper != "") {
        ^$wrapper ...$args
    } else {
        ^muse ...$args
    }
}

# pre_execution hook: report tty + busy state and kick a port scan before a
# command runs.
def --env _hmux_pre_execution [] {
    if not (_hmux_integration_enabled) { return }
    _hmux_report_tty_once
    _hmux_report_shell_activity_state running
    _hmux_ports_kick command
}

# pre_prompt hook: keyboard reset, tty/idle/cwd reports, and a port-scan
# refresh at most every 5 seconds.
def --env _hmux_pre_prompt [] {
    if not (_hmux_integration_enabled) { return }
    _hmux_reset_terminal_leftover_modes
    _hmux_reset_terminal_keyboard_protocols
    _hmux_report_tty_once
    _hmux_report_shell_activity_state prompt
    _hmux_report_pwd_if_changed
    let now = (date now | format date "%s" | into int)
    let last = (($env._HMUX_PORTS_LAST_RUN? | default "0") | into int)
    if ($now - $last) >= 5 { _hmux_ports_kick refresh }
}

if (_hmux_integration_enabled) {
    $env._HMUX_SEND_TOOL = (_hmux_pick_send_tool)
    _hmux_restore_scrollback_once
    _hmux_show_welcome_once
    # String hooks (not closures) so the def --env entry points can persist
    # their dedupe state into the REPL environment.
    $env.config = ($env.config | upsert hooks.pre_execution (
        ($env.config.hooks.pre_execution? | default []) | append "_hmux_pre_execution"
    ))
    $env.config = ($env.config | upsert hooks.pre_prompt (
        ($env.config.hooks.pre_prompt? | default []) | append "_hmux_pre_prompt"
    ))
}
