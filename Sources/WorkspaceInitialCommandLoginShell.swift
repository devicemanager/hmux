import Darwin
import Foundation

enum WorkspaceInitialCommandLoginShell {
    /// Resolves the user's login shell and wraps an externally supplied workspace command.
    ///
    /// Ghostty otherwise launches string commands through Bash with `--noprofile --norc`,
    /// so the user's profile cannot contribute tools such as Homebrew-installed agents.
    /// Ghostty prepends `exec -l`, so the returned command starts with the quoted shell path.
    static func wrap(_ command: String) -> String {
        let databaseShell: String?
        if let record = getpwuid(getuid()),
           let shell = record.pointee.pw_shell {
            let copiedShell = String(cString: shell)
            databaseShell = copiedShell.isEmpty ? nil : copiedShell
        } else {
            databaseShell = nil
        }

        let userShell = databaseShell
            ?? ProcessInfo.processInfo.environment["SHELL"]
            ?? "/bin/zsh"
        return wrap(command, userShell: userShell)
    }

    /// Wraps a command in a supported login shell while preserving the command verbatim.
    ///
    /// Login profiles can prepend other tool directories (Homebrew's `shellenv` puts
    /// `/opt/homebrew/bin` first) ahead of the per-surface shim directory that hmux
    /// seeds into the spawned PATH, which would route `claude`/`codex` around hmux's
    /// wrapper hooks. The payload therefore re-prepends the shim directory after
    /// profiles run; a duplicate PATH entry is harmless and matches what interactive
    /// shell integration already produces. The directory can sit in a shared
    /// temporary directory, so both the root and its ancestors are checked before
    /// any PATH change. The shared agent root also supports Claude-disabled panes.
    static func wrap(_ command: String, userShell: String?) -> String {
        var shellPath: String
        if let userShell, userShell.hasPrefix("/") {
            shellPath = userShell
        } else {
            shellPath = "/bin/zsh"
        }
        let payload: String
        let check = shellSingleQuoted(shimRootCheck)

        switch (shellPath as NSString).lastPathComponent {
        case "fish":
            payload = """
            set -l _hmux_previous_shim ""
            for _hmux_candidate_shim in "$HMUX_CLAUDE_WRAPPER_SHIM_ROOT" "$HMUX_AGENT_COMMAND_SHIM_ROOT"
                if test -n "$_hmux_candidate_shim"; and test "$_hmux_candidate_shim" != "$_hmux_previous_shim"; and /bin/sh -c \(check) hmux "$_hmux_candidate_shim"
                    set -gx PATH "$_hmux_candidate_shim" $PATH
                    set _hmux_previous_shim "$_hmux_candidate_shim"
                end
            end
            set -e _hmux_previous_shim _hmux_candidate_shim
            \(command)
            """
        case "zsh", "bash", "sh", "ksh", "dash":
            payload = """
            \(posixShimRootPrepend)
            \(command)
            """
        default:
            shellPath = "/bin/zsh"
            payload = """
            \(posixShimRootPrepend)
            \(command)
            """
        }

        return "\(shellSingleQuoted(shellPath)) -lc \(shellSingleQuoted(payload))"
    }

    private static var posixShimRootPrepend: String {
        """
        _hmux_previous_shim=''
        for _hmux_candidate_shim in "${HMUX_CLAUDE_WRAPPER_SHIM_ROOT:-}" "${HMUX_AGENT_COMMAND_SHIM_ROOT:-}"; do
            if [ -n "$_hmux_candidate_shim" ] && [ "$_hmux_candidate_shim" != "$_hmux_previous_shim" ] && /bin/sh -c \(shellSingleQuoted(shimRootCheck)) hmux "$_hmux_candidate_shim"; then
                PATH="$_hmux_candidate_shim${PATH:+:$PATH}"; export PATH
                _hmux_previous_shim=$_hmux_candidate_shim
            fi
        done
        unset _hmux_previous_shim _hmux_candidate_shim
        """
    }

    /// The same fixed POSIX predicate runs from every supported login shell;
    /// the candidate is argv data and never interpolated into executable code.
    private static let shimRootCheck = #"""
    _hmux_root=$1
    case "$_hmux_root" in /*) ;; *) exit 1 ;; esac
    while [ "$_hmux_root" != / ] && [ "${_hmux_root%/}" != "$_hmux_root" ]; do _hmux_root=${_hmux_root%/}; done
    [ -d "$_hmux_root" ] && [ ! -L "$_hmux_root" ] || exit 1
    _hmux_uid=$(/usr/bin/id -u) || exit 1
    _hmux_meta() {
        _hmux_info=$(/usr/bin/stat -f '%HT:%u:%Mp%Lp' -- "$1" 2>/dev/null) || _hmux_info=$(/usr/bin/stat -c '%F:%u:%a' -- "$1" 2>/dev/null) || return 1
        _hmux_kind=${_hmux_info%%:*}
        _hmux_info=${_hmux_info#*:}
        _hmux_owner=${_hmux_info%%:*}
        _hmux_mode=${_hmux_info#*:}
        case "$_hmux_mode" in ''|*[!0-7]*) return 1 ;; esac
        _hmux_mode=$((0$_hmux_mode))
    }
    _hmux_chain_safe() {
        _hmux_current=$1
        while :; do
            _hmux_meta "$_hmux_current" || return 1
            [ "$_hmux_owner" = "$_hmux_uid" ] || [ "$_hmux_owner" = 0 ] || return 1
            case "$_hmux_kind" in
                Directory|directory) [ $((_hmux_mode & 0022)) -eq 0 ] || [ $((_hmux_mode & 01000)) -ne 0 ] || return 1 ;;
                'Symbolic Link'|'symbolic link') ;;
                *) return 1 ;;
            esac
            [ "$_hmux_current" = / ] && return 0
            _hmux_current=${_hmux_current%/*}
            [ -n "$_hmux_current" ] || _hmux_current=/
        done
    }
    _hmux_meta "$_hmux_root" || exit 1
    [ "$_hmux_owner" = "$_hmux_uid" ] && [ $((_hmux_mode & 0022)) -eq 0 ] || exit 1
    _hmux_chain_safe "$_hmux_root" || exit 1
    _hmux_resolved=$(CDPATH='' command cd -P "$_hmux_root" >/dev/null && /bin/pwd -P) || exit 1
    _hmux_chain_safe "$_hmux_resolved"
    """#

    private static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
