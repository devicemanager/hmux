import HmuxFoundation
import Foundation

enum RemoteInteractiveShellBootstrapBuilder {
    static func script(
        remoteRelayPort: Int,
        shellFeatures: String,
        initialCommand: String? = nil,
        configuredRemoteCommand: String? = nil,
        terminfoSource: String? = nil,
        bundledZshIntegration: String? = nil,
        bundledBashIntegration: String? = nil,
        bundledFishIntegration: String? = nil,
        terminalProfile: WorkspaceRemoteTerminalProfile = .shell,
        protectsFromHangup: Bool = false
    ) -> String {
        let shellStateDir = shellStateDirForRemoteRelayPort(remoteRelayPort)
        let initialCommandBootstrap = RemoteInitialCommandBootstrap(
            command: initialCommand,
            protectsFromHangup: protectsFromHangup
        )
        let shellExec = shellExecCommand(shell: #""$HMUX_LOGIN_SHELL""#, protectsFromHangup: protectsFromHangup)
        let zshExec = shellExecCommand(shell: #""${SHELL:-/bin/zsh}""#, protectsFromHangup: protectsFromHangup)
        let bashExec = shellExecCommand(shell: #""${SHELL:-/bin/bash}""#, protectsFromHangup: protectsFromHangup)
        let fishExec = shellExecCommand(shell: #""${SHELL:-/bin/fish}""#, protectsFromHangup: protectsFromHangup)
        let fallbackExec = shellExecCommand(shell: #""${SHELL:-/bin/sh}""#, protectsFromHangup: protectsFromHangup)
        let commonShellExportLines = commonShellLines(
            remoteRelayPort: remoteRelayPort,
            shellStateDir: shellStateDir,
            shellFeatures: shellFeatures,
            terminfoSource: terminfoSource
        )
        var zshShellLines = commonShellExportLines
        zshShellLines.append(
            #"if [ "${HMUX_SHELL_INTEGRATION:-1}" != "0" ] && [ -r "${HMUX_SHELL_INTEGRATION_DIR}/hmux-zsh-integration.zsh" ]; then . "${HMUX_SHELL_INTEGRATION_DIR}/hmux-zsh-integration.zsh"; fi"#
        )
        var bashShellLines = commonShellExportLines
        bashShellLines.append(
            #"if [ "${HMUX_SHELL_INTEGRATION:-1}" != "0" ] && [ -r "${HMUX_SHELL_INTEGRATION_DIR}/hmux-bash-integration.bash" ]; then . "${HMUX_SHELL_INTEGRATION_DIR}/hmux-bash-integration.bash"; fi"#
        )
        bashShellLines.append(contentsOf: initialCommandBootstrap.posixInteractiveShellLines)
        let zshBootstrap = RemoteRelayZshBootstrap(shellStateDir: shellStateDir)
        let relayWarmupLines = relayWarmupLines(remoteRelayPort: remoteRelayPort)
        // A captured/approved startup command is an explicit restore target;
        // it takes precedence over the host's default interactive program.
        // Launching the configured command with `-c` would bypass the shell
        // hooks that atomically claim and execute the startup command.
        let chainedRemoteCommand = terminalProfile.kind == .shell && !initialCommandBootstrap.hasCommand
            ? configuredRemoteCommand?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        let chainedRemoteCommandLaunch = chainedRemoteCommand.flatMap { command -> String? in
            guard !command.isEmpty else { return nil }
            // Match sshd's normal RemoteCommand execution through the account shell.
            return "\(shellExec) -c \(shellQuote(command))"
        }

        var outerLines: [String] = [
            "mkdir -p \"$HOME/.hmux/relay\"",
            "hmux_shell_dir=\"\(shellStateDir)\"",
            "mkdir -p \"$hmux_shell_dir\"",
        ]
        outerLines.append(contentsOf: claudeWrapperInstallLines)
        outerLines.append(contentsOf: initialCommandBootstrap.preparationLines)
        if let bundledZshIntegration {
            outerLines += [
                "cat > \"$hmux_shell_dir/hmux-zsh-integration.zsh\" <<'HMUXHMUXZSH'",
                bundledZshIntegration,
                "HMUXHMUXZSH",
            ]
        }
        if let bundledBashIntegration {
            outerLines += [
                "cat > \"$hmux_shell_dir/hmux-bash-integration.bash\" <<'HMUXHMUXBASH'",
                bundledBashIntegration,
                "HMUXHMUXBASH",
            ]
        }
        if let bundledFishIntegration {
            outerLines += [
                "mkdir -p \"$hmux_shell_dir/fish\"",
                "cat > \"$hmux_shell_dir/fish/config.fish\" <<'HMUXHMUXFISH'",
                bundledFishIntegration,
                "HMUXHMUXFISH",
            ]
        }
        outerLines.append(contentsOf: commonShellExportLines + Self.remoteInitialWorkingDirectoryLines())
        outerLines += [
            "HMUX_LOGIN_SHELL=\"${SHELL:-/bin/zsh}\"",
            protectsFromHangup
                ? "if [ -z \"${HMUX_PERSISTENT_PTY_EXEC_HELPER:-}\" ] || [ ! -x \"$HMUX_PERSISTENT_PTY_EXEC_HELPER\" ]; then exit 126; fi"
                : ":",
            "case \"${HMUX_LOGIN_SHELL##*/}\" in",
            "  zsh)",
            "    cat > \"$hmux_shell_dir/.zshenv\" <<'HMUXZSHENV'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshEnvLines)
        outerLines += [
            "HMUXZSHENV",
            "    cat > \"$hmux_shell_dir/.zprofile\" <<'HMUXZSHPROFILE'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshProfileLines)
        outerLines += [
            "HMUXZSHPROFILE",
            "    cat > \"$hmux_shell_dir/.zshrc\" <<'HMUXZSHRC'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshRCLines(commonShellLines: zshShellLines))
        outerLines += [
            "HMUXZSHRC",
            "    cat > \"$hmux_shell_dir/.zlogin\" <<'HMUXZSHLOGIN'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshLoginLines + initialCommandBootstrap.posixInteractiveShellLines)
        outerLines += [
            "HMUXZSHLOGIN",
            "    chmod 600 \"$hmux_shell_dir/.zshenv\" \"$hmux_shell_dir/.zprofile\" \"$hmux_shell_dir/.zshrc\" \"$hmux_shell_dir/.zlogin\" >/dev/null 2>&1 || true",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        outerLines += [
            "    export HMUX_REAL_ZDOTDIR=\"${ZDOTDIR:-$HOME}\"",
            "    export ZDOTDIR=\"$hmux_shell_dir\"",
            terminalLaunchLine(
                profile: terminalProfile,
                indentation: "    ",
                directShellCommand: chainedRemoteCommandLaunch
                    ?? "\(shellExec) -il",
                tmuxShellCommand: "export HMUX_REAL_ZDOTDIR=\"${HMUX_REAL_ZDOTDIR:-${ZDOTDIR:-$HOME}}\"; export ZDOTDIR=\"\(shellStateDir)\"; \(zshExec) -il"
            ),
            "    ;;",
            "  bash)",
            "    cat > \"$hmux_shell_dir/.bashrc\" <<'HMUXBASHRC'",
        ]
        outerLines.append(contentsOf: [
            "if [ -f \"$HOME/.bash_profile\" ]; then",
            "  . \"$HOME/.bash_profile\"",
            "elif [ -f \"$HOME/.bash_login\" ]; then",
            "  . \"$HOME/.bash_login\"",
            "elif [ -f \"$HOME/.profile\" ]; then",
            "  . \"$HOME/.profile\"",
            "fi",
            "[ -f \"$HOME/.bashrc\" ] && . \"$HOME/.bashrc\"",
        ] + bashShellLines)
        outerLines += [
            "HMUXBASHRC",
            "    chmod 600 \"$hmux_shell_dir/.bashrc\" >/dev/null 2>&1 || true",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        outerLines += [
            terminalLaunchLine(
                profile: terminalProfile,
                indentation: "    ",
                directShellCommand: chainedRemoteCommandLaunch
                    ?? "\(shellExec) --rcfile \"$hmux_shell_dir/.bashrc\" -i",
                // tmux stores `default-command` at the session level. Resolve
                // the relay directory from the session environment each time
                // a pane is created so reconnects cannot leave new panes
                // pointing at a deleted relay rcfile.
                tmuxShellCommand: "\(bashExec) --rcfile \"${HMUX_SHELL_INTEGRATION_DIR:-\(shellStateDir)}/.bashrc\" -i"
            ),
            "    ;;",
            "  fish)",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        var fishInitCommands = ["source \"$HMUX_FISH_INTEGRATION_FILE\""]
        if let initialCommand = initialCommandBootstrap.fishInteractiveShellCommand {
            fishInitCommands.append(initialCommand)
        }
        let fishInitCommand = shellQuote(fishInitCommands.joined(separator: "; "))
        outerLines += [
            "    export HMUX_FISH_INTEGRATION_FILE=\"$hmux_shell_dir/fish/config.fish\"",
            "    export HMUX_FISH_USER_CONFIG_ALREADY_LOADED=1",
            terminalLaunchLine(
                profile: terminalProfile,
                indentation: "    ",
                directShellCommand: chainedRemoteCommandLaunch
                    ?? "\(shellExec) -il --init-command \(fishInitCommand)",
                tmuxShellCommand: "export HMUX_FISH_INTEGRATION_FILE=\"\(shellStateDir)/fish/config.fish\"; export HMUX_FISH_USER_CONFIG_ALREADY_LOADED=1; \(fishExec) -il --init-command \(fishInitCommand)"
            ),
            "    ;;",
            "  *)",
        ]
        outerLines.append(contentsOf: relayWarmupLines)
        outerLines.append(contentsOf: initialCommandBootstrap.fallbackShellLines)
        outerLines += [
            terminalLaunchLine(
                profile: terminalProfile,
                indentation: "",
                directShellCommand: chainedRemoteCommandLaunch
                    ?? "\(shellExec) -i",
                tmuxShellCommand: "\(fallbackExec) -i"
            ),
            ";;",
            "esac",
        ]

        return outerLines.joined(separator: "\n")
    }

    /// Persistent daemon PTYs outlive their transport; ordinary SSH and Mosh
    /// shells retain normal hangup handling when their transport goes away.
    static func shellExecCommand(shell: String, protectsFromHangup: Bool) -> String {
        if protectsFromHangup {
            return "exec \"$HMUX_PERSISTENT_PTY_EXEC_HELPER\" --internal-persistent-pty-exec \(shell) \(shell)"
        }
        return "exec \(shell)"
    }

    private static func terminalLaunchLine(
        profile: WorkspaceRemoteTerminalProfile,
        indentation: String,
        directShellCommand: String,
        tmuxShellCommand: String
    ) -> String {
        guard let sessionName = profile.tmuxSessionName else {
            return indentation + directShellCommand
        }
        let command = RemoteTmuxSessionCommandBuilder(
            sessionName: sessionName,
            shellCommand: tmuxShellCommand
        ).remoteShellCommand
        return indentation + "exec " + command
    }

    static func shellFeatures(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let rawExisting = environment["GHOSTTY_SHELL_FEATURES"] ?? ""
        var seen: Set<String> = []
        var merged: [String] = []

        for token in rawExisting.split(separator: ",") {
            let feature = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !feature.isEmpty else { continue }
            if seen.insert(feature).inserted {
                merged.append(feature)
            }
        }

        for required in ["ssh-env", "ssh-terminfo"] {
            if seen.insert(required).inserted {
                merged.append(required)
            }
        }

        return merged.joined(separator: ",")
    }

    static func bundledShellIntegrationScript(
        named fileName: String,
        bundleResourceURL: URL? = Bundle.main.resourceURL,
        fileManager: FileManager = .default
    ) -> String? {
        guard let bundleResourceURL else { return nil }
        let url = bundleResourceURL
            .appendingPathComponent("shell-integration", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else {
            return nil
        }
        return contents
    }

    private static func commonShellLines(
        remoteRelayPort: Int,
        shellStateDir: String,
        shellFeatures: String,
        terminfoSource: String?
    ) -> [String] {
        let relaySocket = remoteRelayPort > 0 ? "127.0.0.1:\(remoteRelayPort)" : nil
        var lines = terminalSetupLines(terminfoSource: terminfoSource)
        lines.append(contentsOf: RemoteShellEnvironment.utf8LocaleSetupLines())
        lines.append(contentsOf: shellExportLines(shellFeatures: shellFeatures))
        lines.append("export PATH=\"$HOME/.hmux/bin:$PATH\"")
        lines.append("export HMUX_BUNDLED_CLI_PATH=\"$HOME/.hmux/bin/hmux\"")
        lines.append("unset HMUX_CODEX_WRAPPER_SHIM; if [ -x \"$HOME/.hmux/bin/hmux-codex-wrapper\" ] && command -v bash >/dev/null 2>&1; then export HMUX_CODEX_WRAPPER_SHIM=\"$HOME/.hmux/bin/hmux-codex-wrapper\"; fi")
        lines.append(
            "export HMUX_PERSISTENT_PTY_EXEC_HELPER=\"${HMUX_PERSISTENT_PTY_EXEC_HELPER:-$HMUX_BUNDLED_CLI_PATH}\""
        )
        lines.append("export HMUX_SHELL_INTEGRATION_DIR=\"\(shellStateDir)\"")
        if let relaySocket {
            lines.append("export HMUX_SOCKET_PATH=\(relaySocket)")
        }
        // The assignment placeholders are replaced by `ssh-pty-attach` before
        // this script runs. Split the sentinel patterns so a missed replacement
        // does not export literal placeholder IDs into the remote shell.
        lines.append(contentsOf: [
            "hmux_workspace_id='__HMUX_WORKSPACE_ID__'",
            "case \"$hmux_workspace_id\" in \"\"|'__HMUX_''WORKSPACE_ID__') ;; *) export HMUX_WORKSPACE_ID=\"$hmux_workspace_id\"; export HMUX_TAB_ID=\"$hmux_workspace_id\" ;; esac",
            "hmux_surface_id='__HMUX_SURFACE_ID__'",
            "case \"$hmux_surface_id\" in \"\"|'__HMUX_''SURFACE_ID__') ;; *) export HMUX_SURFACE_ID=\"$hmux_surface_id\"; export HMUX_PANEL_ID=\"$hmux_surface_id\" ;; esac",
            "hmux_terminal_lifecycle_id='__HMUX_TERMINAL_LIFECYCLE_ID__'",
            "case \"$hmux_terminal_lifecycle_id\" in \"\"|'__HMUX_''TERMINAL_LIFECYCLE_ID__') ;; *) export HMUX_TERMINAL_LIFECYCLE_ID=\"$hmux_terminal_lifecycle_id\" ;; esac",
            "hmux_ssh_attempt_id='__HMUX_SSH_ATTEMPT_ID__'",
            "case \"$hmux_ssh_attempt_id\" in \"\"|'__HMUX_''SSH_ATTEMPT_ID__') ;; *) export HMUX_SSH_ATTEMPT_ID=\"$hmux_ssh_attempt_id\" ;; esac",
            "unset hmux_workspace_id hmux_surface_id hmux_terminal_lifecycle_id hmux_ssh_attempt_id",
            "hash -r >/dev/null 2>&1 || true",
            "rehash >/dev/null 2>&1 || true",
        ])
        return lines
    }

    static func terminalSetupLines(terminfoSource: String?) -> [String] {
        let trimmedTerminfoSource = terminfoSource?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedTerminfoSource, !trimmedTerminfoSource.isEmpty else {
            // Without a bundled terminfo to install we can only probe what the
            // remote already has and fall back to a universally-present entry.
            return [
                "hmux_term='xterm-256color'",
                "if command -v infocmp >/dev/null 2>&1 && infocmp xterm-ghostty >/dev/null 2>&1; then",
                "  hmux_term='xterm-ghostty'",
                "fi",
                "export TERM=\"$hmux_term\"",
            ]
        }
        // Install the bundled xterm-ghostty terminfo *synchronously*, before
        // deciding TERM, so a full-screen TUI (e.g. Claude Code) never starts
        // against a TERM whose terminfo entry is missing or half-written.
        //
        // The previous design deferred `tic` to a background job and decided
        // TERM up front, so the first shell on a host without the entry got
        // xterm-256color while a later pass could select xterm-ghostty mid-write
        // and garble output (#6352). Here we compile into a private temp
        // directory on the same filesystem as ~/.terminfo, then move each
        // compiled entry into place with an atomic rename, so a concurrent reader
        // in another hmux ssh session sharing $HOME never observes a partially
        // written database. The temp directory comes from `mktemp` when present,
        // otherwise a per-process `$$` directory (unique among live processes) so
        // the atomic-rename path applies even without `mktemp` — no branch ever
        // compiles terminfo directly into ~/.terminfo.
        return [
            "hmux_term='xterm-256color'",
            "if command -v infocmp >/dev/null 2>&1 && infocmp xterm-ghostty >/dev/null 2>&1; then",
            "  hmux_term='xterm-ghostty'",
            "elif command -v tic >/dev/null 2>&1; then",
            "  mkdir -p \"$HOME/.terminfo\" 2>/dev/null",
            "  hmux_ti_tmp=$(mktemp -d \"$HOME/.terminfo.hmux.XXXXXX\" 2>/dev/null) || hmux_ti_tmp=''",
            "  if [ -z \"$hmux_ti_tmp\" ]; then",
            "    hmux_ti_tmp=\"$HOME/.terminfo.hmux.$$\"",
            "    rm -rf \"$hmux_ti_tmp\" 2>/dev/null",
            "    mkdir \"$hmux_ti_tmp\" 2>/dev/null || hmux_ti_tmp=''",
            "  fi",
            "  {",
            "    cat <<'HMUXTERMINFO'",
            trimmedTerminfoSource,
            "HMUXTERMINFO",
            "  } | {",
            "    if [ -n \"$hmux_ti_tmp\" ] && tic -x -o \"$hmux_ti_tmp\" - >/dev/null 2>&1; then",
            "      find \"$hmux_ti_tmp\" -type f 2>/dev/null | while IFS= read -r hmux_ti_file; do",
            "        hmux_ti_rel=${hmux_ti_file#\"$hmux_ti_tmp\"/}",
            "        hmux_ti_dest=\"$HOME/.terminfo/$hmux_ti_rel\"",
            "        mkdir -p \"$(dirname \"$hmux_ti_dest\")\" 2>/dev/null",
            "        mv -f \"$hmux_ti_file\" \"$hmux_ti_dest\" 2>/dev/null || cp -f \"$hmux_ti_file\" \"$hmux_ti_dest\" 2>/dev/null",
            "      done",
            "    fi",
            "  }",
            "  [ -n \"$hmux_ti_tmp\" ] && rm -rf \"$hmux_ti_tmp\" 2>/dev/null",
            "  if infocmp xterm-ghostty >/dev/null 2>&1; then",
            "    hmux_term='xterm-ghostty'",
            "  fi",
            "  unset hmux_ti_tmp hmux_ti_file hmux_ti_rel hmux_ti_dest 2>/dev/null || true",
            "fi",
            "export TERM=\"$hmux_term\"",
        ]
    }

    private static func shellExportLines(shellFeatures: String) -> [String] {
        let environment = ProcessInfo.processInfo.environment
        let colorTerm = normalizedEnvValue(environment["COLORTERM"]) ?? "truecolor"
        let termProgram = normalizedEnvValue(environment["TERM_PROGRAM"]) ?? "ghostty"
        let termProgramVersion = normalizedEnvValue(environment["TERM_PROGRAM_VERSION"])
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? ""
        let trimmedShellFeatures = shellFeatures.trimmingCharacters(in: .whitespacesAndNewlines)

        var exports: [String] = [
            "export COLORTERM=\(shellQuote(colorTerm))",
            "export TERM_PROGRAM=\(shellQuote(termProgram))",
        ]
        if !termProgramVersion.isEmpty {
            exports.append("export TERM_PROGRAM_VERSION=\(shellQuote(termProgramVersion))")
        }
        if !trimmedShellFeatures.isEmpty {
            exports.append("export GHOSTTY_SHELL_FEATURES=\(shellQuote(trimmedShellFeatures))")
        }
        return exports
    }

    private static func relayWarmupLines(remoteRelayPort: Int) -> [String] {
        guard remoteRelayPort > 0 else {
            return []
        }
        return [
            "hmux_relay_cli=\"${HMUX_BUNDLED_CLI_PATH:-$HOME/.hmux/bin/hmux}\"",
            "if [ ! -x \"$hmux_relay_cli\" ]; then hmux_relay_cli=\"$(command -v hmux 2>/dev/null || true)\"; fi",
            "hmux_relay_tty=\"${HMUX_BOOTSTRAP_TTY:-}\"",
            "if [ -z \"$hmux_relay_tty\" ]; then hmux_relay_tty=\"$(tty 2>/dev/null || true)\"; fi",
            "hmux_relay_tty=\"${hmux_relay_tty##*/}\"",
            "if [ -n \"$hmux_relay_tty\" ] && [ \"$hmux_relay_tty\" != \"not a tty\" ]; then",
            "  mkdir -p \"$HOME/.hmux/relay\" >/dev/null 2>&1 || true",
            "  printf '%s' \"$hmux_relay_tty\" > \"$HOME/.hmux/relay/\(remoteRelayPort).tty\" 2>/dev/null || true",
            "fi",
            "if [ -n \"$hmux_relay_cli\" ] && [ -n \"$HMUX_WORKSPACE_ID\" ] && [ -n \"$HMUX_TERMINAL_LIFECYCLE_ID\" ] && [ -n \"$HMUX_SSH_ATTEMPT_ID\" ] && [ -n \"$hmux_relay_tty\" ] && [ \"$hmux_relay_tty\" != \"not a tty\" ]; then",
            "  hmux_relay_report_tty=\"{\\\"workspace_id\\\":\\\"$HMUX_WORKSPACE_ID\\\",\\\"tty_name\\\":\\\"$hmux_relay_tty\\\",\\\"terminal_lifecycle_id\\\":\\\"$HMUX_TERMINAL_LIFECYCLE_ID\\\",\\\"attempt_id\\\":\\\"$HMUX_SSH_ATTEMPT_ID\\\"}\"",
            "  hmux_relay_ports_kick=\"{\\\"workspace_id\\\":\\\"$HMUX_WORKSPACE_ID\\\",\\\"reason\\\":\\\"command\\\"}\"",
            "  if [ -n \"$HMUX_SURFACE_ID\" ]; then",
            "    hmux_relay_report_tty=\"{\\\"workspace_id\\\":\\\"$HMUX_WORKSPACE_ID\\\",\\\"surface_id\\\":\\\"$HMUX_SURFACE_ID\\\",\\\"tty_name\\\":\\\"$hmux_relay_tty\\\",\\\"terminal_lifecycle_id\\\":\\\"$HMUX_TERMINAL_LIFECYCLE_ID\\\",\\\"attempt_id\\\":\\\"$HMUX_SSH_ATTEMPT_ID\\\"}\"",
            "    hmux_relay_ports_kick=\"{\\\"workspace_id\\\":\\\"$HMUX_WORKSPACE_ID\\\",\\\"surface_id\\\":\\\"$HMUX_SURFACE_ID\\\",\\\"reason\\\":\\\"command\\\"}\"",
            "  fi",
            "  \"$hmux_relay_cli\" rpc surface.report_tty \"$hmux_relay_report_tty\" >/dev/null 2>&1 || true",
            "  ( \"$hmux_relay_cli\" rpc surface.ports_kick \"$hmux_relay_ports_kick\" >/dev/null 2>&1 || true ) </dev/null >/dev/null 2>&1 &",
            "fi",
            "unset HMUX_BOOTSTRAP_TTY hmux_relay_cli hmux_relay_tty hmux_relay_report_tty hmux_relay_ports_kick",
        ]
    }

    /// The shell integration's `claude` shim execs
    /// `$HMUX_SHELL_INTEGRATION_DIR/bin/hmux-claude-wrapper` when present. On a
    /// relay host that wrapper hands off to the remote CLI, which injects the
    /// relay hooks through `--settings`, so launchers that resolve `claude`
    /// from PATH (and set their own CLAUDE_CONFIG_DIR) still report status.
    /// An older remote CLI without the verb fails the local `--hmux-probe`
    /// (no relay round trip), so the wrapper falls back to plain `claude`.
    static let claudeWrapperInstallLines: [String] = [
        "mkdir -p \"$hmux_shell_dir/bin\"",
        "cat > \"$hmux_shell_dir/bin/hmux-claude-wrapper\" <<'HMUXCLAUDEWRAPPER'",
        "#!/bin/sh",
        "hmux_cli=\"$HOME/.hmux/bin/hmux\"",
        "if [ -x \"$hmux_cli\" ] && \"$hmux_cli\" claude-wrapper --hmux-probe >/dev/null 2>&1; then exec \"$hmux_cli\" claude-wrapper \"$@\"; fi",
        "hmux_path=",
        "hmux_ifs=$IFS; IFS=:",
        "for hmux_entry in $PATH; do case \"$hmux_entry\" in *hmux-cli-shims*) ;; *) hmux_path=\"${hmux_path:+$hmux_path:}$hmux_entry\" ;; esac; done",
        "IFS=$hmux_ifs; PATH=$hmux_path; export PATH",
        "exec claude \"$@\"",
        "HMUXCLAUDEWRAPPER",
        "chmod 700 \"$hmux_shell_dir/bin/hmux-claude-wrapper\"",
    ]

    private static func shellStateDirForRemoteRelayPort(_ remoteRelayPort: Int) -> String {
        "$HOME/.hmux/relay/\(max(remoteRelayPort, 0)).shell"
    }

    private static func normalizedEnvValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func shellQuote(_ value: String) -> String {
        value.posixShellWord
    }
}
