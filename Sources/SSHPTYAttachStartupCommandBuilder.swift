import Foundation
import HmuxCore
import HmuxFoundation

enum SSHPTYAttachStartupCommandBuilder {
    struct ForegroundAuth {
        let destination: String
        let port: Int?
        let identityFile: String?
        let sshOptions: [String]
        /// The route state a ``WorkspaceRemoteConfiguration`` keeps beside
        /// its options, so the merge still picks the route's private master.
        let routeSensitivity: WorkspaceRemoteRouteSensitivity
        let token: String
        let postAuthenticationCommand: String?

        init(
            destination: String,
            port: Int?,
            identityFile: String?,
            sshOptions: [String],
            routeSensitivity: WorkspaceRemoteRouteSensitivity = .shared,
            token: String,
            postAuthenticationCommand: String? = nil
        ) {
            self.destination = destination
            self.port = port
            self.identityFile = identityFile
            self.sshOptions = sshOptions
            self.routeSensitivity = routeSensitivity
            self.token = token
            self.postAuthenticationCommand = postAuthenticationCommand
        }
    }

    static func command(
        sessionID: String? = nil,
        foregroundAuth: ForegroundAuth? = nil,
        remoteCommand: String? = nil,
        requireExisting: Bool = true
    ) -> String {
        let backoffBuilder = SSHRetryBackoffScriptBuilder(context: .attach)
        var lines = [
            "hmux_ssh_attach_cli=\"${HMUX_BUNDLED_CLI_PATH:-}\"",
            "if [ -z \"$hmux_ssh_attach_cli\" ] || [ ! -x \"$hmux_ssh_attach_cli\" ]; then hmux_ssh_attach_cli=\"$(command -v hmux 2>/dev/null || true)\"; fi",
            "if [ -z \"$hmux_ssh_attach_cli\" ]; then printf '%s\\n' '[hmux] bundled CLI not found for SSH PTY attach.' >&2; exit 127; fi",
            "if [ -z \"${HMUX_SOCKET_PATH:-}\" ]; then printf '%s\\n' '[hmux] required configuration missing for SSH PTY attach.' >&2; exit 1; fi",
            "if [ -z \"${HMUX_WORKSPACE_ID:-}\" ]; then printf '%s\\n' '[hmux] required workspace context missing for SSH PTY attach.' >&2; exit 1; fi",
        ]
        if let sessionID = normalized(sessionID) {
            lines.append("hmux_ssh_attach_session_id=\(shellQuote(sessionID))")
        } else {
            lines += [
                "hmux_ssh_attach_session_id=\"${HMUX_SSH_PTY_SESSION_ID:-}\"",
                "if [ -z \"$hmux_ssh_attach_session_id\" ]; then if [ -z \"${HMUX_SURFACE_ID:-}\" ]; then printf '%s\\n' '[hmux] required terminal context missing for SSH PTY attach.' >&2; exit 1; fi; hmux_ssh_attach_session_id=\"ssh-$HMUX_WORKSPACE_ID-$HMUX_SURFACE_ID\"; fi",
            ]
        }
        if let foregroundAuth {
            // The app passes the token in the environment. Keep it in a shell
            // variable for every retry, and out of the environment of the
            // commands this script starts.
            lines += SSHForegroundAuthenticationLaunch(token: foregroundAuth.token)
                .tokenLoadShellLines(into: "hmux_ssh_attach_auth_token")
            lines += foregroundAuthLines(foregroundAuth)
            lines.append(
                SSHForegroundAuthenticationRetryPolicy().processTreeTerminationShellFunction()
            )
        }
        lines.append("hmux_ssh_attach_lifecycle_id=\"${HMUX_SSH_PTY_LIFECYCLE_ID:-}\"")
        lines.append("if [ -z \"$hmux_ssh_attach_lifecycle_id\" ]; then hmux_ssh_attach_lifecycle_id=$(/usr/bin/uuidgen | /usr/bin/tr '[:upper:]' '[:lower:]') || exit 1; fi")
        lines += [
            "hmux_ssh_attach_lifecycle_ended=0",
            "hmux_ssh_attach_auth_pid=",
            "hmux_ssh_attach_auth_event_token=",
            "hmux_ssh_attach_lifecycle_end() { if [ \"$hmux_ssh_attach_lifecycle_ended\" = 1 ]; then return; fi; hmux_ssh_attach_lifecycle_ended=1; \"$hmux_ssh_attach_cli\" --socket \"$HMUX_SOCKET_PATH\" ssh-session-end --lifecycle-only --workspace \"$HMUX_WORKSPACE_ID\" --surface \"${HMUX_SURFACE_ID:-}\" --terminal-lifecycle-id \"${HMUX_TERMINAL_LIFECYCLE_ID:-}\" --session-id \"$hmux_ssh_attach_session_id\" --lifecycle-id \"$hmux_ssh_attach_lifecycle_id\" >/dev/null 2>&1 || true; }",
            "hmux_ssh_attach_signal_exit() { hmux_ssh_attach_signal_status=\"$1\"; hmux_ssh_attach_signal_name=\"$2\"; if [ -n \"${hmux_ssh_attach_auth_pid:-}\" ]; then hmux_ssh_terminate_auth_process_tree \"$hmux_ssh_attach_auth_pid\" \"$$\" 1 \"${hmux_ssh_attach_auth_event_token:-}\"; wait \"$hmux_ssh_attach_auth_pid\" 2>/dev/null || true; hmux_ssh_attach_auth_pid=; \(backoffBuilder.signalHandlerBranches) elif [ \"${hmux_ssh_attach_auth_launching:-0}\" = 1 ]; then hmux_ssh_attach_pending_signal=\"$hmux_ssh_attach_signal_status\"; hmux_ssh_attach_pending_signal_name=\"$hmux_ssh_attach_signal_name\"; return; fi; hmux_ssh_attach_restore_terminal; trap - EXIT HUP INT TERM; hmux_ssh_attach_lifecycle_end; exit \"$hmux_ssh_attach_signal_status\"; }",
            "trap 'hmux_ssh_attach_lifecycle_end' EXIT",
            "trap 'hmux_ssh_attach_signal_exit 129 HUP' HUP",
            "trap 'hmux_ssh_attach_signal_exit 130 INT' INT",
            "trap 'hmux_ssh_attach_signal_exit 143 TERM' TERM",
        ]
        let requireExistingFlag = requireExisting ? " --require-existing" : ""
        let commandB64Flag = normalized(remoteCommand).map {
            " --command-b64 \(shellQuote(Data($0.utf8).base64EncodedString()))"
        } ?? ""
        let attachCommand = "\"$hmux_ssh_attach_cli\" --socket \"$HMUX_SOCKET_PATH\" ssh-pty-attach --wait\(requireExistingFlag) --workspace \"$HMUX_WORKSPACE_ID\" --session-id \"$hmux_ssh_attach_session_id\" --lifecycle-id \"$hmux_ssh_attach_lifecycle_id\" --attachment-id \"${HMUX_SURFACE_ID:-}\"\(commandB64Flag)"
        lines += [
            "hmux_ssh_attach_register_attempt() { hmux_ssh_attach_launch_payload=\"{\\\"workspace_id\\\":\\\"$HMUX_WORKSPACE_ID\\\",\\\"surface_id\\\":\\\"${HMUX_SURFACE_ID:-}\\\",\\\"terminal_lifecycle_id\\\":\\\"${HMUX_TERMINAL_LIFECYCLE_ID:-}\\\",\\\"attempt_id\\\":\\\"$HMUX_SSH_ATTEMPT_ID\\\"}\"; HMUXTERM_CLI_RESPONSE_TIMEOUT_SEC=2 \"$hmux_ssh_attach_cli\" --socket \"$HMUX_SOCKET_PATH\" rpc workspace.remote.terminal_session_launching \"$hmux_ssh_attach_launch_payload\" >/dev/null 2>&1; }",
        ] + SSHPTYAttachRetryScriptBuilder().launchRegistrationRetryLines(functionPrefix: "hmux_ssh_attach") + [
            "hmux_ssh_attach_attempt() { hmux_ssh_attach_begin_attempt || return \"$?\"; \(attachCommand); }",
        ]
        lines += SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_ssh_attach_attempt",
            reauthenticates: foregroundAuth != nil
        )
        return "/bin/sh -c \(shellQuote(lines.joined(separator: "\n")))"
    }

    static func restoredRemoteShellCommand(
        relayPort: Int,
        initialCommand: String? = nil,
        configuredRemoteCommand: String? = nil
    ) -> String {
        RemoteInteractiveShellBootstrapBuilder.script(
            remoteRelayPort: relayPort,
            shellFeatures: RemoteInteractiveShellBootstrapBuilder.shellFeatures(),
            initialCommand: initialCommand,
            configuredRemoteCommand: configuredRemoteCommand,
            bundledZshIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "hmux-zsh-integration.zsh"),
            bundledBashIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "hmux-bash-integration.bash"),
            bundledFishIntegration: RemoteInteractiveShellBootstrapBuilder.bundledShellIntegrationScript(named: "fish/config.fish"),
            protectsFromHangup: true
        )
    }

    private static func foregroundAuthLines(_ auth: ForegroundAuth) -> [String] {
        let readinessInsideResolvedLock =
            foregroundAuthenticationReadyShellLines(
                includeResolvedControlPath: true,
                requireSuccess: true,
                cliVariable: "HMUX_SSH_ATTACH_CLI"
            )
        let (sshCommand, reportsReadiness) =
            sshForegroundAuthCommand(
                auth,
                successShellLines: readinessInsideResolvedLock
            )
        var lines = [
            "hmux_ssh_attach_foreground_auth() {",
            "  \(sshCommand)",
            "hmux_ssh_auth_status=$?",
            "  if [ \"$hmux_ssh_auth_status\" -ne 0 ]; then return \"$hmux_ssh_auth_status\"; fi",
        ]
        if !reportsReadiness {
            lines.append("hmux_ssh_auth_token=\"$hmux_ssh_attach_auth_token\";")
            lines += foregroundAuthenticationReadyShellLines(
                includeResolvedControlPath: false,
                requireSuccess: false,
                cliVariable: "hmux_ssh_attach_cli"
            )
        }
        if let postAuthenticationCommand = normalized(auth.postAuthenticationCommand) {
            lines += [
                "  \(postAuthenticationCommand)",
                "  hmux_ssh_post_auth_status=$?",
                "  if [ \"$hmux_ssh_post_auth_status\" -ne 0 ]; then return \"$hmux_ssh_post_auth_status\"; fi",
                "  unset hmux_ssh_post_auth_status",
            ]
        }
        lines += [
            "unset hmux_ssh_auth_status",
            "}",
        ]
        return lines
    }

    private static func sshForegroundAuthCommand(
        _ auth: ForegroundAuth,
        successShellLines: [String]
    ) -> (command: String, reportsReadiness: Bool) {
        let sharingOptions = SSHConnectionSharingOptions()
        var arguments = ["/usr/bin/ssh"]
        let options = SSHAgentSocketResolver().removingOptions(
            named: "RemoteCommand",
            from: sharingOptions.mergingDefaults(
                into: auth.sshOptions,
                routeSensitiveOptions: (auth.identityFile.map { ["IdentityFile=\($0)"] } ?? [])
                    + auth.routeSensitivity.markerOptions,
                routeIdentifier: {
                    guard case .identified(let identifier) = auth.routeSensitivity else { return nil }
                    return identifier
                }()
            )
        )
        if !hasSSHOptionKey(options, key: "ConnectTimeout") {
            arguments += ["-o", "ConnectTimeout=6"]
        }
        if !hasSSHOptionKey(options, key: "ServerAliveInterval") {
            arguments += ["-o", "ServerAliveInterval=20"]
        }
        if !hasSSHOptionKey(options, key: "ServerAliveCountMax") {
            arguments += ["-o", "ServerAliveCountMax=2"]
        }
        if let port = auth.port {
            arguments += ["-p", String(port)]
        }
        if let identityFile = normalized(auth.identityFile) {
            arguments += ["-i", identityFile]
        }
        for option in options {
            arguments += ["-o", option]
        }
        // The command-line `true` below conflicts with a host-configured
        // RemoteCommand unless overridden (issue #7246).
        arguments += SSHHostConfiguredRemoteCommand().overrideArguments
        let preflight = sharingOptions.controlPathPreflightShellFunction(
            sshArguments: arguments,
            destination: auth.destination,
            options: options
        )
        let resolvedAuthenticationLockLines =
            resolvedControlMasterAuthenticationLockLines(
                sharingOptions: sharingOptions,
                sshArguments: arguments,
                destination: auth.destination,
                options: options
            )
        arguments += ["-T", "--", auth.destination, "true"]
        let command = arguments.map(shellQuote).joined(separator: " ")
        guard let lockPath = sharingOptions.foregroundAuthenticationLockPath(
            destination: auth.destination,
            port: auth.port,
            options: options
        ) else {
            return (
                SSHForegroundAuthenticationRetryPolicy()
                    .classifyingTransientFailure(in: command),
                false
            )
        }
        let inFlightPath = lockPath + ".inflight"
        var lockedCommand = SSHForegroundAuthenticationLaunch(token: auth.token)
            .tokenLoadShellLines(into: "hmux_ssh_auth_token")
        lockedCommand += [
            "umask 077",
            "hmux_ssh_auth_inflight_path=\(shellQuote(inFlightPath))",
            "hmux_ssh_auth_lock_path=\(shellQuote(lockPath))",
            "printf '%s\\n' \"$$\" > \"$hmux_ssh_auth_inflight_path\" || exit 255",
            "hmux_ssh_clear_auth_inflight() { if [ \"$(/bin/cat -- \"$hmux_ssh_auth_inflight_path\" 2>/dev/null || true)\" = \"$$\" ]; then /bin/rm -f -- \"$hmux_ssh_auth_inflight_path\" 2>/dev/null || true; fi; }",
            "trap 'hmux_ssh_clear_auth_inflight' EXIT",
            "trap 'hmux_ssh_clear_auth_inflight; exit 129' HUP",
            "trap 'hmux_ssh_clear_auth_inflight; exit 130' INT",
            "trap 'hmux_ssh_clear_auth_inflight; exit 143' TERM",
            ": >> \"$hmux_ssh_auth_lock_path\" || exit 255",
            "zmodload zsh/system || exit 255",
            "zsystem flock -t 45 -e -f hmux_ssh_auth_lock_fd \"$hmux_ssh_auth_lock_path\" || exit 255",
        ]
        lockedCommand += resolvedAuthenticationLockLines
        lockedCommand += [
            preflight,
            preflight == nil ? nil : "hmux_ssh_preflight_control_path",
            "command \(command)",
            "hmux_ssh_auth_status=$?",
            "if [ \"$hmux_ssh_auth_status\" -ne 0 ]; then exit \"$hmux_ssh_auth_status\"; fi",
        ].compactMap { $0 }
        lockedCommand += successShellLines
        lockedCommand += sharingOptions.successfulForegroundAuthenticationCleanupShellLines()
        lockedCommand.append("exit 0")
        let classifiedCommand = SSHForegroundAuthenticationRetryPolicy()
            .classifyingTransientFailure(in: lockedCommand.joined(separator: "\n"))
        let tokenEnvironment = SSHForegroundAuthenticationLaunch
            .environmentAssignment(from: "hmux_ssh_attach_auth_token")
        return (
            "\(tokenEnvironment) HMUX_SSH_ATTACH_CLI=\"$hmux_ssh_attach_cli\" \(classifiedCommand)",
            true
        )
    }

    private static func foregroundAuthenticationReadyShellLines(
        includeResolvedControlPath: Bool,
        requireSuccess: Bool,
        cliVariable: String
    ) -> [String] {
        SSHForegroundAuthenticationLaunch.readyShellLines(
            tokenVariable: "hmux_ssh_auth_token",
            payloadVariable: "hmux_ssh_auth_payload",
            cliVariable: cliVariable,
            socketVariable: "HMUX_SOCKET_PATH",
            controlPathVariable: includeResolvedControlPath
                ? "hmux_ssh_resolved_control_path"
                : nil,
            requireSuccess: requireSuccess
        )
    }

    private static func resolvedControlMasterAuthenticationLockLines(
        sharingOptions: SSHConnectionSharingOptions,
        sshArguments: [String],
        destination: String,
        options: [String]
    ) -> [String] {
        guard sharingOptions.hmuxOwnedControlPath(in: options) != nil,
              let socketPattern = sharingOptions.resolvedControlPathShellPattern else {
            return []
        }
        let sshPrefix = sshArguments.map(shellQuote).joined(separator: " ")
        let quotedDestination = shellQuote(destination)
        let lockPrefix = URL(
            fileURLWithPath: sharingOptions.controlMasterLockDirectoryPath,
            isDirectory: true
        )
        .appendingPathComponent(
            "hmux-ssh-\(sharingOptions.userID)-resolved-auth-",
            isDirectory: false
        )
        .path
        return [
            #"hmux_ssh_resolved_control_path="$(command \#(sshPrefix) -G \#(quotedDestination) 2>/dev/null | awk 'tolower($1) == "controlpath" { $1 = ""; sub(/^[[:space:]]+/, ""); print; exit }')" "#,
            "case \"$hmux_ssh_resolved_control_path\" in",
            "  \(socketPattern)) ;;",
            "  *) exit 255 ;;",
            "esac",
            "hmux_ssh_resolved_control_basename=\"${hmux_ssh_resolved_control_path##*/}\"",
            "case \"$hmux_ssh_resolved_control_basename\" in ''|*[!A-Za-z0-9._-]*) exit 255 ;; esac",
            "hmux_ssh_resolved_auth_lock_path=\(shellQuote(lockPrefix))\"$hmux_ssh_resolved_control_basename.lock\"",
            ": >> \"$hmux_ssh_resolved_auth_lock_path\" || exit 255",
            "zsystem flock -t 45 -e -f hmux_ssh_resolved_auth_lock_fd \"$hmux_ssh_resolved_auth_lock_path\" || exit 255",
        ]
    }

    static func sshOptionsWithRestoreControlDefaults(_ options: [String], relayPort: Int? = nil) -> [String] {
        _ = relayPort
        return SSHConnectionSharingOptions().mergingDefaults(into: options)
    }

    static func sshOptionsSupportReusableForegroundAuth(_ options: [String]) -> Bool {
        guard !hasSSHOptionKey(options, key: "LocalCommand"),
              !hasSSHOptionKey(options, key: "PermitLocalCommand") else {
            return false
        }

        guard let controlPath = sshOptionValue(named: "ControlPath", in: options),
              !controlPath.isEmpty,
              controlPath.lowercased() != "none" else {
            return false
        }

        if sshOptionValueIsDisabled(sshOptionValue(named: "ControlMaster", in: options)) {
            return false
        }

        return !sshOptionValueIsDisabled(
            sshOptionValue(named: "ControlPersist", in: options),
            zeroIsDisabled: false
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func hasSSHOptionKey(_ options: [String], key: String) -> Bool {
        SSHAgentSocketResolver().hasOptionKey(options, key: key)
    }

    private static func sshOptionValue(named name: String, in options: [String]) -> String? {
        SSHAgentSocketResolver().optionValue(named: name, in: options)
    }

    private static func sshOptionValueIsDisabled(_ rawValue: String?, zeroIsDisabled: Bool = true) -> Bool {
        guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["no", "false", "off"].contains(normalized) || (zeroIsDisabled && normalized == "0")
    }

    private static func shellQuote(_ value: String) -> String {
        value.posixShellWord
    }
}
