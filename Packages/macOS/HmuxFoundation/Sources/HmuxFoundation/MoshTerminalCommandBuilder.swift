internal import Foundation

/// Builds a Mosh terminal command with explicit SSH capability fallback.
///
/// The builder receives complete SSH argument prefixes from the caller so the
/// Mosh capability probe and bootstrap honor the same host alias, identity,
/// port, and OpenSSH options as the workspace control connection.
public struct MoshTerminalCommandBuilder: Sendable {
    private let capabilityProbeSSHArguments: [String]
    private let sessionSSHArguments: [String]
    private let localMoshExecutableName: String
    private let destination: String
    private let remoteCommandArguments: [String]
    private let remoteRelayPort: Int?
    private let remoteIPMode: MoshRemoteIPMode
    private let preparationShellScript: String?
    private let managementReadyShellScript: String?
    private let sshFallbackCommand: String
    private let sshFallbackLauncherPaths: [String]
    private let localMoshMissingMessage: String
    private let localMoshUnsupportedMessage: String
    private let remoteMoshMissingMessage: String
    private let remoteMoshProbeFailedMessage: String
    private let remoteBootstrapInstallFailedMessage: String
    private let remoteMoshAddressFallbackMessage: String

    /// Creates a Mosh terminal command builder.
    ///
    /// - Parameters:
    ///   - localMoshExecutableName: Local executable basename; injectable for deterministic tests.
    ///   - capabilityProbeSSHArguments: SSH executable and options used to check for `mosh-server`.
    ///   - sessionSSHArguments: SSH executable and options passed to Mosh's `--ssh` bootstrap.
    ///   - destination: SSH destination or host alias.
    ///   - remoteCommandArguments: Optional command argv launched by `mosh-server`.
    ///   - remoteRelayPort: Optional remote relay whose presence enables authoritative lifecycle attempt registration.
    ///   - remoteIPMode: Address-discovery mode passed to Mosh; remote mode falls back to SSH proxy resolution when SSH advertises an unusable address.
    ///   - preparationShellScript: Optional local preparation run before capability checks.
    ///   - managementReadyShellScript: Optional local callback run after SSH preparation succeeds and before Mosh starts.
    ///   - sshFallbackCommand: Complete local SSH terminal command used when Mosh is unavailable.
    ///   - sshFallbackLauncherPaths: Launcher files that only `sshFallbackCommand` runs. Each deletes
    ///     itself when it runs, so they are removed before Mosh replaces the shell.
    ///   - localMoshMissingMessage: User-facing message printed when no local `mosh` executable exists.
    ///   - localMoshUnsupportedMessage: User-facing message printed when local Mosh lacks the required remote-IP mode.
    ///   - remoteMoshMissingMessage: User-facing message printed when `mosh-server` is absent remotely.
    ///   - remoteMoshProbeFailedMessage: User-facing message printed when the remote capability probe fails.
    ///   - remoteBootstrapInstallFailedMessage: User-facing message printed when bootstrap staging fails.
    ///   - remoteMoshAddressFallbackMessage: User-facing message printed when SSH proxy address resolution is selected automatically.
    public init(
        capabilityProbeSSHArguments: [String],
        sessionSSHArguments: [String],
        localMoshExecutableName: String = "mosh",
        destination: String,
        remoteCommandArguments: [String],
        remoteRelayPort: Int? = nil,
        remoteIPMode: MoshRemoteIPMode = .remote,
        preparationShellScript: String? = nil,
        managementReadyShellScript: String? = nil,
        sshFallbackCommand: String,
        sshFallbackLauncherPaths: [String] = [],
        localMoshMissingMessage: String,
        localMoshUnsupportedMessage: String,
        remoteMoshMissingMessage: String,
        remoteMoshProbeFailedMessage: String,
        remoteBootstrapInstallFailedMessage: String,
        remoteMoshAddressFallbackMessage: String
    ) {
        self.capabilityProbeSSHArguments = capabilityProbeSSHArguments
        self.sessionSSHArguments = sessionSSHArguments
        self.localMoshExecutableName = localMoshExecutableName
        self.destination = destination
        self.remoteCommandArguments = remoteCommandArguments
        self.remoteRelayPort = remoteRelayPort
        self.remoteIPMode = remoteIPMode
        self.preparationShellScript = preparationShellScript
        self.managementReadyShellScript = managementReadyShellScript
        self.sshFallbackCommand = sshFallbackCommand
        self.sshFallbackLauncherPaths = sshFallbackLauncherPaths
        self.localMoshMissingMessage = localMoshMissingMessage
        self.localMoshUnsupportedMessage = localMoshUnsupportedMessage
        self.remoteMoshMissingMessage = remoteMoshMissingMessage
        self.remoteMoshProbeFailedMessage = remoteMoshProbeFailedMessage
        self.remoteBootstrapInstallFailedMessage = remoteBootstrapInstallFailedMessage
        self.remoteMoshAddressFallbackMessage = remoteMoshAddressFallbackMessage
    }

    /// Returns a shell command that launches Mosh or falls back to SSH.
    ///
    /// Capability detection happens before Mosh starts: the local executable is
    /// resolved from `PATH`, then the remote host is checked for `mosh-server`
    /// through the supplied SSH management lane. Exit status 127 represents an
    /// honest remote-missing result; other probe failures use the generic SSH
    /// fallback without pretending Mosh support was confirmed.
    ///
    /// - Returns: A complete `/bin/sh -c` terminal startup command.
    public func command() -> String {
        let localMoshResolver = RemoteExecutableCommandBuilder(
            executableName: localMoshExecutableName,
            notFoundSentinel: "hmux-mosh: local mosh not found"
        )
        let remoteMoshServerResolver = RemoteExecutableCommandBuilder(
            executableName: "mosh-server",
            notFoundSentinel: "hmux-mosh: remote mosh-server not found"
        )
        let remoteCapabilityCommand =
            remoteMoshServerResolver.resolutionProbeShellCommand + " >/dev/null 2>&1"
        let capabilityProbe = (capabilityProbeSSHArguments + [
            "-T",
            destination,
            remoteCapabilityCommand,
        ])
            .map(\.remoteCommandShellQuoted)
            .joined(separator: " ")
        let remoteSSHConnectionScript = "printf '%s\\n' \"__HMUX_SSH_CONNECTION__${SSH_CONNECTION:-}\""
        let remoteSSHConnectionCommand = "/bin/sh -c \(remoteSSHConnectionScript.remoteCommandShellQuoted)"
        let remoteSSHConnectionProbe = (capabilityProbeSSHArguments + [
            "-T",
            destination,
            remoteSSHConnectionCommand,
        ])
            .map(\.remoteCommandShellQuoted)
            .joined(separator: " ")
        let moshSSHCommand = sessionSSHArguments
            .map(\.remoteCommandShellQuoted)
            .joined(separator: " ")
        let moshArguments = ([
            "--ssh=\(moshSSHCommand)",
            "--server=\(remoteMoshServerResolver.remoteExecPrefixShellCommand)",
            "--",
            destination,
        ] + remoteCommandArguments)
            .map(\.remoteCommandShellQuoted)
            .joined(separator: " ")
        var script = [
            "hmux_mosh_fallback() { exec /bin/sh -c \(sshFallbackCommand.remoteCommandShellQuoted); }",
            "hmux_mosh=\"$(\(localMoshResolver.resolutionProbeShellCommand) 2>/dev/null)\"",
            "hmux_mosh_resolve_status=$?",
            "if [ \"$hmux_mosh_resolve_status\" -ne 0 ] || [ -z \"$hmux_mosh\" ]; then",
            "  printf '%s\\n' \(localMoshMissingMessage.remoteCommandShellQuoted) >&2",
            "  hmux_mosh_fallback",
            "fi",
            "unset hmux_mosh_resolve_status",
            "hmux_mosh_help=$(\"$hmux_mosh\" --help 2>&1 || true)",
            "case \"$hmux_mosh_help\" in",
            "  *--experimental-remote-ip=*) ;;",
            "  *)",
            "    printf '%s\\n' \(localMoshUnsupportedMessage.remoteCommandShellQuoted) >&2",
            "    hmux_mosh_fallback",
            "    ;;",
            "esac",
            "unset hmux_mosh_help",
        ]
        let reportsTerminalLifecycle = remoteRelayPort.map { (1...65_535).contains($0) } ?? false
        if reportsTerminalLifecycle {
            script += terminalLifecycleAttemptShellLines()
        }
        if let preparationShellScript = preparationShellScript?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !preparationShellScript.isEmpty {
            script += [
                preparationShellScript,
                "hmux_mosh_prepare_status=$?",
                "if [ \"$hmux_mosh_prepare_status\" -ne 0 ]; then",
                "  printf '%s\\n' \(remoteBootstrapInstallFailedMessage.remoteCommandShellQuoted) >&2",
                "  hmux_mosh_fallback",
                "fi",
                "unset hmux_mosh_prepare_status hmux_remote_install_status",
            ]
        }
        script += [
            "hmux_mosh_remote_ip_mode=\(remoteIPMode.rawValue.remoteCommandShellQuoted)",
            "hmux_mosh_address_fallback=0",
        ]
        script += [
            capabilityProbe,
            "hmux_mosh_probe_status=$?",
            "if [ \"$hmux_mosh_probe_status\" -eq 127 ]; then",
            "  printf '%s\\n' \(remoteMoshMissingMessage.remoteCommandShellQuoted) >&2",
            "  hmux_mosh_fallback",
            "fi",
            "if [ \"$hmux_mosh_probe_status\" -ne 0 ]; then",
            "  printf '%s\\n' \(remoteMoshProbeFailedMessage.remoteCommandShellQuoted) >&2",
            "  hmux_mosh_fallback",
            "fi",
        ]
        if remoteIPMode == .remote {
            // Mosh parses SSH_CONNECTION as four space-separated fields with
            // numeric ports and uses only the server address for its UDP
            // session, so validate exactly that shape and no more. When the
            // advertised address is unusable (empty, malformed, wildcard, or
            // loopback, which is what a port-forwarded SSH alias reports),
            // fall back to Mosh's proxy resolution: unlike local mode it
            // honors SSH aliases without requiring DNS on the destination.
            script += [
                "hmux_mosh_ssh_connection_probe_status=0",
                "hmux_mosh_ssh_connection_probe=\"$(\(remoteSSHConnectionProbe) 2>/dev/null)\" || hmux_mosh_ssh_connection_probe_status=$?",
                "case \"$hmux_mosh_ssh_connection_probe\" in *__HMUX_SSH_CONNECTION__*) hmux_mosh_ssh_connection=\"${hmux_mosh_ssh_connection_probe##*__HMUX_SSH_CONNECTION__}\" ;; *) hmux_mosh_ssh_connection= ;; esac",
                "if [ \"$hmux_mosh_ssh_connection_probe_status\" -ne 0 ] || [ -z \"$hmux_mosh_ssh_connection\" ]; then",
                "  hmux_mosh_address_fallback=1",
                "else",
                "  case \"$hmux_mosh_ssh_connection\" in",
                "    *' '*' '*' '*)",
                "      hmux_mosh_ssh_connection_tail=\"${hmux_mosh_ssh_connection#* }\"",
                "      hmux_mosh_ssh_peer_port=\"${hmux_mosh_ssh_connection_tail%% *}\"",
                "      hmux_mosh_ssh_connection_tail=\"${hmux_mosh_ssh_connection_tail#* }\"",
                "      hmux_mosh_ssh_server_ip=\"${hmux_mosh_ssh_connection_tail%% *}\"",
                "      hmux_mosh_ssh_connection_tail=\"${hmux_mosh_ssh_connection_tail#* }\"",
                "      hmux_mosh_ssh_server_port=\"${hmux_mosh_ssh_connection_tail%% *}\"",
                "      case \"$hmux_mosh_ssh_peer_port\" in ''|*[!0-9]*) hmux_mosh_address_fallback=1 ;; esac",
                "      case \"$hmux_mosh_ssh_server_port\" in ''|*[!0-9]*) hmux_mosh_address_fallback=1 ;; esac",
                "      case \"$hmux_mosh_ssh_server_ip\" in ''|0.0.0.0|::|::0|::1|127.*) hmux_mosh_address_fallback=1 ;; *[!0-9A-Fa-f:.]*) hmux_mosh_address_fallback=1 ;; esac",
                "      ;;",
                "    *) hmux_mosh_address_fallback=1 ;;",
                "  esac",
                "fi",
                "if [ \"$hmux_mosh_address_fallback\" -eq 1 ]; then hmux_mosh_remote_ip_mode=proxy; fi",
                "unset hmux_mosh_ssh_connection_probe_status hmux_mosh_ssh_connection_probe hmux_mosh_ssh_connection hmux_mosh_ssh_peer_port hmux_mosh_ssh_connection_tail hmux_mosh_ssh_server_ip hmux_mosh_ssh_server_port",
            ]
        }
        script += [
            "if [ \"$hmux_mosh_address_fallback\" -eq 1 ]; then",
            "  printf '%s\\n' \(remoteMoshAddressFallbackMessage.remoteCommandShellQuoted) >&2",
            "fi",
            "unset hmux_mosh_probe_status hmux_mosh_address_fallback",
        ]
        if let managementReadyShellScript = managementReadyShellScript?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !managementReadyShellScript.isEmpty {
            script.append(managementReadyShellScript)
        }
        if reportsTerminalLifecycle {
            script += terminalLifecycleRegistrationShellLines()
        }
        // Past this point the SSH fallback can no longer run, so its
        // self-deleting launchers never would; remove them before Mosh
        // replaces this shell.
        if !sshFallbackLauncherPaths.isEmpty {
            script.append(
                "rm -f -- " + sshFallbackLauncherPaths.map(\.remoteCommandShellQuoted).joined(separator: " ")
            )
        }
        // Mosh exposes no reliable post-UDP-handshake callback, so this
        // pre-exec launcher must not claim authoritative connected readiness.
        script.append("exec \"$hmux_mosh\" \"--experimental-remote-ip=$hmux_mosh_remote_ip_mode\" \(moshArguments)")
        return "/bin/sh -c \(script.joined(separator: "\n").remoteCommandShellQuoted)"
    }

    private func terminalLifecycleAttemptShellLines() -> [String] {
        [
            "HMUX_SSH_ATTEMPT_ID=$(/usr/bin/uuidgen | /usr/bin/tr '[:upper:]' '[:lower:]') || hmux_mosh_fallback",
            "export HMUX_SSH_ATTEMPT_ID",
        ]
    }

    private func terminalLifecycleRegistrationShellLines() -> [String] {
        [
            "hmux_mosh_lifecycle_cli=\"${HMUX_BUNDLED_CLI_PATH:-}\"",
            "if [ -z \"$hmux_mosh_lifecycle_cli\" ] || [ ! -x \"$hmux_mosh_lifecycle_cli\" ]; then hmux_mosh_lifecycle_cli=\"$(command -v hmux 2>/dev/null || true)\"; fi",
            "if [ -z \"$hmux_mosh_lifecycle_cli\" ] || [ -z \"${HMUX_SOCKET_PATH:-}\" ] || [ -z \"${HMUX_WORKSPACE_ID:-}\" ] || [ -z \"${HMUX_SURFACE_ID:-}\" ] || [ -z \"${HMUX_TERMINAL_LIFECYCLE_ID:-}\" ]; then hmux_mosh_fallback; fi",
            "hmux_mosh_lifecycle_rpc() { hmux_mosh_lifecycle_method=\"$1\"; hmux_mosh_lifecycle_payload=\"$2\"; hmux_mosh_lifecycle_retry=0; while ! HMUXTERM_CLI_RESPONSE_TIMEOUT_SEC=2 \"$hmux_mosh_lifecycle_cli\" --socket \"$HMUX_SOCKET_PATH\" rpc \"$hmux_mosh_lifecycle_method\" \"$hmux_mosh_lifecycle_payload\" >/dev/null 2>&1; do hmux_mosh_lifecycle_retry=$((hmux_mosh_lifecycle_retry + 1)); if [ \"$hmux_mosh_lifecycle_retry\" -ge 4 ]; then return 1; fi; /bin/sleep 0.1; done; }",
            "hmux_mosh_launch_payload=\"{\\\"workspace_id\\\":\\\"$HMUX_WORKSPACE_ID\\\",\\\"surface_id\\\":\\\"$HMUX_SURFACE_ID\\\",\\\"terminal_lifecycle_id\\\":\\\"$HMUX_TERMINAL_LIFECYCLE_ID\\\",\\\"attempt_id\\\":\\\"$HMUX_SSH_ATTEMPT_ID\\\"}\"",
            "hmux_mosh_lifecycle_rpc workspace.remote.terminal_session_launching \"$hmux_mosh_launch_payload\" || hmux_mosh_fallback",
            "unset hmux_mosh_launch_payload hmux_mosh_lifecycle_cli hmux_mosh_lifecycle_method hmux_mosh_lifecycle_payload hmux_mosh_lifecycle_retry",
            "unset -f hmux_mosh_lifecycle_rpc 2>/dev/null || true",
        ]
    }
}
