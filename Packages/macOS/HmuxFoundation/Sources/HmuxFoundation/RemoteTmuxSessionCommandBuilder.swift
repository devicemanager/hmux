internal import Foundation

/// Builds a terminal-attached tmux session launcher with shell integration.
///
/// A new session receives the supplied shell command for both its first pane
/// and future windows. Before attaching an existing session, its hmux workspace
/// environment is rebound to the current relay without changing user options
/// or already-running commands.
public struct RemoteTmuxSessionCommandBuilder: Sendable {
    private let sessionName: String
    private let shellCommand: String

    /// Creates a named tmux session launcher.
    ///
    /// - Parameters:
    ///   - sessionName: Validated exact tmux session name.
    ///   - shellCommand: Shell command used for panes in a newly created session.
    public init(sessionName: String, shellCommand: String) {
        self.sessionName = sessionName
        self.shellCommand = shellCommand
    }

    /// A shell-quoted command that creates or attaches to the named session.
    public var remoteShellCommand: String {
        let resolver = RemoteExecutableCommandBuilder(
            executableName: "tmux",
            notFoundSentinel: RemoteTmuxCommandBuilder.notFoundSentinel
        )
        var scriptLines = [
            "hmux_session_name=$1",
            "hmux_shell_command=$2",
            "hmux_session_target=\"=$hmux_session_name\"",
            "hmux_tmux=\"$(\(resolver.resolutionProbeShellCommand))\" || exit $?",
            "if \"$hmux_tmux\" has-session -t \"$hmux_session_target\" 2>/dev/null; then",
        ]
        scriptLines.append(contentsOf: Self.workspaceEnvironmentRebindingLines.map { "  " + $0 })
        scriptLines += [
            #"  hmux_default_command="$("$hmux_tmux" show-options -v -t "$hmux_session_target:" default-command 2>/dev/null || true)""#,
            // A failed refresh stops the reconnect before it attaches. The
            // message is hmux's own; tmux's diagnostic stays on the remote.
            #"  case "$hmux_default_command" in *HMUX_PERSISTENT_PTY_EXEC_HELPER*|*HMUX_SHELL_INTEGRATION_DIR*) "$hmux_tmux" set-option -t "$hmux_session_target:" default-command "$hmux_shell_command" >/dev/null 2>/dev/null || { hmux_status=$?; printf 'hmux: could not update the shell command of tmux session %s\n' "$hmux_session_name" >&2; exit "$hmux_status"; } ;; esac"#,
            "  unset hmux_default_command",
            "  exec \"$hmux_tmux\" attach-session -t \"$hmux_session_target\"",
            "fi",
            "if \"$hmux_tmux\" new-session -d \(Self.newSessionEnvironmentArguments) -s \"$hmux_session_name\" \"$hmux_shell_command\"; then",
        ]
        scriptLines.append(contentsOf: Self.workspaceEnvironmentRebindingLines.map { "  " + $0 })
        scriptLines += [
            "  \"$hmux_tmux\" set-option -t \"$hmux_session_target:\" default-command \"$hmux_shell_command\" >/dev/null || exit $?",
            "fi",
            "exec \"$hmux_tmux\" attach-session -t \"$hmux_session_target\"",
        ]
        let script = scriptLines.joined(separator: "\n")
        return ([
            "/bin/sh",
            "-c",
            script,
            "hmux-remote-tmux-session",
            sessionName,
            shellCommand,
        ])
        .map(\.remoteCommandShellQuoted)
        .joined(separator: " ")
    }

    private static let workspaceEnvironmentKeys = [
        "HMUX_BUNDLED_CLI_PATH",
        "HMUX_PERSISTENT_PTY_EXEC_HELPER",
        "HMUX_SHELL_INTEGRATION",
        "HMUX_SHELL_INTEGRATION_DIR",
        "HMUX_SOCKET_PATH",
        "HMUX_SSH_ATTEMPT_ID",
        "HMUX_TAB_ID",
        "HMUX_TERMINAL_LIFECYCLE_ID",
        "HMUX_WORKSPACE_ID",
    ]

    private static let surfaceEnvironmentKeys = [
        "HMUX_PANEL_ID",
        "HMUX_SURFACE_ID",
    ]

    private static let transientEnvironmentKeys = [
        "HMUX_INITIAL_COMMAND_FILE",
    ]

    private static var workspaceEnvironmentRebindingLines: [String] {
        workspaceEnvironmentKeys.map { key in
            "if [ \"${\(key)+x}\" = x ]; then \"$hmux_tmux\" set-environment -t \"$hmux_session_target\" \(key) \"$\(key)\" >/dev/null || exit $?; else \"$hmux_tmux\" set-environment -t \"$hmux_session_target\" -u \(key) >/dev/null || exit $?; fi"
        } + transientEnvironmentClearingLines + surfaceEnvironmentClearingLines
    }

    private static var newSessionEnvironmentArguments: String {
        let workspaceArguments = workspaceEnvironmentKeys.map { key in
            "-e \"\(key)=${\(key)-}\""
        }
        let transientArguments = transientEnvironmentKeys.map { key in
            "-e \"\(key)=${\(key)-}\""
        }
        let surfaceArguments = surfaceEnvironmentKeys.map { key in
            "-e \"\(key)=\""
        }
        return (workspaceArguments + transientArguments + surfaceArguments).joined(separator: " ")
    }

    private static var transientEnvironmentClearingLines: [String] {
        transientEnvironmentKeys.map { key in
            "\"$hmux_tmux\" set-environment -t \"$hmux_session_target\" -u \(key) >/dev/null || exit $?"
        }
    }

    private static var surfaceEnvironmentClearingLines: [String] {
        surfaceEnvironmentKeys.map { key in
            "\"$hmux_tmux\" set-environment -t \"$hmux_session_target\" -u \(key) >/dev/null || exit $?"
        }
    }
}
