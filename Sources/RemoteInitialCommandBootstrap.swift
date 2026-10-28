import Foundation

/// Stages a remote workspace command for one execution by the first interactive shell.
struct RemoteInitialCommandBootstrap {
    private let encodedCommand: String?
    private let protectsFromHangup: Bool
    /// Embedded in the persisted bootstrap so reattaches reuse it while later workspaces do not.
    private let stateKey = UUID().uuidString.lowercased()

    init(command: String?, protectsFromHangup: Bool = false) {
        self.protectsFromHangup = protectsFromHangup
        guard let command,
              !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            encodedCommand = nil
            return
        }
        encodedCommand = Data(command.utf8).base64EncodedString()
    }

    /// Whether an explicit startup command will be claimed by the interactive shell.
    var hasCommand: Bool {
        encodedCommand != nil
    }

    /// Stages the command without evaluating any of its contents in the local shell.
    var preparationLines: [String] {
        guard let encodedCommand else { return [] }
        return [
            "unset HMUX_INITIAL_COMMAND_FILE",
            "hmux_initial_command_started=\"$hmux_shell_dir/.initial-command.started.\(stateKey)\"",
            "if [ ! -d \"$hmux_initial_command_started\" ]; then",
            "  hmux_initial_command_file=\"$hmux_shell_dir/.initial-command.payload.\(stateKey).$$\"",
            "  hmux_initial_command_tmp=\"$hmux_initial_command_file.tmp\"",
            "  if (umask 077; printf %s '\(encodedCommand)' > \"$hmux_initial_command_tmp\") && mv -f -- \"$hmux_initial_command_tmp\" \"$hmux_initial_command_file\"; then",
            "    chmod 600 \"$hmux_initial_command_file\" >/dev/null 2>&1 || true",
            "    export HMUX_INITIAL_COMMAND_FILE=\"$hmux_initial_command_file\"",
            "  else",
            "    rm -f -- \"$hmux_initial_command_tmp\" \"$hmux_initial_command_file\" 2>/dev/null || true",
            "  fi",
            "  unset hmux_initial_command_file hmux_initial_command_tmp",
            "fi",
            "unset hmux_initial_command_started",
        ]
    }

    /// Decodes, atomically claims, and runs the command after zsh or bash startup files load.
    var posixInteractiveShellLines: [String] {
        guard encodedCommand != nil else { return [] }
        return [
            "hmux_initial_command_file=\"${HMUX_INITIAL_COMMAND_FILE:-}\"",
            "hmux_initial_command_started=\"$HMUX_SHELL_INTEGRATION_DIR/.initial-command.started.\(stateKey)\"",
            "unset hmux_initial_command_b64 hmux_initial_command hmux_initial_command_decode_status hmux_initial_command_file_status",
            "if [ -r \"$hmux_initial_command_file\" ]; then",
            "  hmux_initial_command_b64=$(cat -- \"$hmux_initial_command_file\" 2>/dev/null)",
            "  hmux_initial_command_file_status=$?",
            "else",
            "  hmux_initial_command_file_status=1",
            "fi",
            "unset HMUX_INITIAL_COMMAND_FILE",
            "if [ -n \"$hmux_initial_command_file\" ]; then rm -f -- \"$hmux_initial_command_file\" 2>/dev/null || true; fi",
            "if [ \"$hmux_initial_command_file_status\" -eq 0 ] && [ -n \"$hmux_initial_command_b64\" ]; then",
            "  hmux_initial_command=$(printf %s \"$hmux_initial_command_b64\" | base64 -d 2>/dev/null || printf %s \"$hmux_initial_command_b64\" | base64 -D 2>/dev/null)",
            "  hmux_initial_command_decode_status=$?",
            "  if [ \"$hmux_initial_command_decode_status\" -eq 0 ] && mkdir \"$hmux_initial_command_started\" 2>/dev/null; then eval \"$hmux_initial_command\"; fi",
            "fi",
            "unset hmux_initial_command_b64 hmux_initial_command hmux_initial_command_decode_status hmux_initial_command_file_status hmux_initial_command_file hmux_initial_command_started",
        ]
    }

    /// Decodes, atomically claims, and runs the command from fish's initialization hook.
    var fishInteractiveShellCommand: String? {
        guard encodedCommand != nil else { return nil }
        return [
            "set -l hmux_initial_command_file \"$HMUX_INITIAL_COMMAND_FILE\"",
            "set -l hmux_initial_command_started \"$HMUX_SHELL_INTEGRATION_DIR/.initial-command.started.\(stateKey)\"",
            "set -l hmux_initial_command_b64",
            "set -l hmux_initial_command_file_status 1",
            "if test -r \"$hmux_initial_command_file\"",
            "set hmux_initial_command_b64 (command cat -- \"$hmux_initial_command_file\" 2>/dev/null)",
            "set hmux_initial_command_file_status $status",
            "end",
            "set -e HMUX_INITIAL_COMMAND_FILE",
            "if test -n \"$hmux_initial_command_file\"; command rm -f -- \"$hmux_initial_command_file\" >/dev/null 2>&1; or true; end",
            "if test \"$hmux_initial_command_file_status\" -eq 0; and test -n \"$hmux_initial_command_b64\"",
            "set -l hmux_initial_command_decode_flag",
            "if printf %s \"$hmux_initial_command_b64\" | base64 -d >/dev/null 2>&1",
            "set hmux_initial_command_decode_flag -d",
            "else if printf %s \"$hmux_initial_command_b64\" | base64 -D >/dev/null 2>&1",
            "set hmux_initial_command_decode_flag -D",
            "end",
            "if test -n \"$hmux_initial_command_decode_flag\"",
            "set -l hmux_initial_command (printf %s \"$hmux_initial_command_b64\" | base64 \"$hmux_initial_command_decode_flag\" 2>/dev/null | string collect)",
            "if command mkdir \"$hmux_initial_command_started\" 2>/dev/null; eval \"$hmux_initial_command\"; end",
            "end",
            "end",
        ].joined(separator: "; ")
    }

    /// Runs the command through shell-specific adapters, with a POSIX wrapper for unknown shells.
    var fallbackShellLines: [String] {
        guard encodedCommand != nil else { return [] }
        let shellExec = RemoteInteractiveShellBootstrapBuilder.shellExecCommand(
            shell: #""$HMUX_LOGIN_SHELL""#,
            protectsFromHangup: protectsFromHangup
        )
        let fallbackExec = RemoteInteractiveShellBootstrapBuilder.shellExecCommand(
            shell: "/bin/sh",
            protectsFromHangup: protectsFromHangup
        )
        return [
            "hmux_initial_command_file=\"${HMUX_INITIAL_COMMAND_FILE:-}\"",
            "hmux_initial_command_started=\"$HMUX_SHELL_INTEGRATION_DIR/.initial-command.started.\(stateKey)\"",
            "unset hmux_initial_command_b64 hmux_initial_command hmux_initial_command_decode_status hmux_initial_command_file_status",
            "if [ -r \"$hmux_initial_command_file\" ]; then",
            "  hmux_initial_command_b64=$(cat -- \"$hmux_initial_command_file\" 2>/dev/null)",
            "  hmux_initial_command_file_status=$?",
            "else",
            "  hmux_initial_command_file_status=1",
            "fi",
            "unset HMUX_INITIAL_COMMAND_FILE",
            "if [ -n \"$hmux_initial_command_file\" ]; then rm -f -- \"$hmux_initial_command_file\" 2>/dev/null || true; fi",
            "if [ \"$hmux_initial_command_file_status\" -eq 0 ] && [ -n \"$hmux_initial_command_b64\" ]; then",
            "  hmux_initial_command=$(printf %s \"$hmux_initial_command_b64\" | base64 -d 2>/dev/null || printf %s \"$hmux_initial_command_b64\" | base64 -D 2>/dev/null)",
            "  hmux_initial_command_decode_status=$?",
            "  if [ \"$hmux_initial_command_decode_status\" -eq 0 ]; then",
            "    case \"${HMUX_LOGIN_SHELL##*/}\" in",
            "      csh|tcsh) if mkdir \"$hmux_initial_command_started\" 2>/dev/null; then \(shellExec) -i -c 'eval \"$argv[2]\"; exec \"$argv[1]\" -i' \"$HMUX_LOGIN_SHELL\" \"$hmux_initial_command\"; fi ;;",
            "      sh|dash|ksh|mksh|ash|yash|posh) if mkdir \"$hmux_initial_command_started\" 2>/dev/null; then \(shellExec) -i -c 'eval \"$1\"; exec \"$0\" -i' \"$HMUX_LOGIN_SHELL\" \"$hmux_initial_command\"; fi ;;",
            // Nushell src/command.rs: --execute runs then stays interactive; --commands exits.
            "      nu|nushell) if mkdir \"$hmux_initial_command_started\" 2>/dev/null; then \(shellExec) --execute \"$hmux_initial_command\"; fi ;;",
            "      pwsh|powershell) if mkdir \"$hmux_initial_command_started\" 2>/dev/null; then \(shellExec) -NoExit -Command \"$hmux_initial_command\"; fi ;;",
            "      *) if mkdir \"$hmux_initial_command_started\" 2>/dev/null; then \(fallbackExec) -c 'eval \"$1\"; exec \"$2\" -i' hmux-initial-command \"$hmux_initial_command\" \"$HMUX_LOGIN_SHELL\"; fi ;;",
            "    esac",
            "  fi",
            "fi",
            "unset hmux_initial_command_b64 hmux_initial_command hmux_initial_command_decode_status hmux_initial_command_file_status hmux_initial_command_file hmux_initial_command_started",
        ]
    }
}
