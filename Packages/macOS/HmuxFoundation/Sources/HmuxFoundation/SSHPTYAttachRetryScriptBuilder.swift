internal import Foundation

/// Builds the shared shell retry state machine for persistent SSH PTY attachment.
///
/// Both app-restored terminals and CLI-created attach commands use this builder
/// so retry limits, backoff, authentication phases, and exit-status handling
/// cannot drift between entrypoints.
public struct SSHPTYAttachRetryScriptBuilder: Sendable {
    /// Creates a persistent SSH PTY retry script builder.
    public init() {}

    /// Builds the shared launch acknowledgement retry functions.
    ///
    /// The caller defines ``<prefix>_register_attempt`` to invoke the local
    /// lifecycle RPC. A timeout is returned as the dedicated launch timeout
    /// status after three acknowledgement attempts; other failures retain
    /// their original status so stale lifecycle rejections remain terminal.
    ///
    /// - Parameter functionPrefix: The shell function prefix, such as
    ///   `hmux_ssh` or `hmux_ssh_attach`.
    /// - Returns: Shell lines for the bounded registration loop.
    public func launchRegistrationRetryLines(functionPrefix: String) -> [String] {
        [
            "\(functionPrefix)_registration_timed_out=0",
            "\(functionPrefix)_begin_attempt() { \(functionPrefix)_registration_timed_out=0; HMUX_SSH_ATTEMPT_ID=$(/usr/bin/uuidgen | /usr/bin/tr '[:upper:]' '[:lower:]') || return 1; export HMUX_SSH_ATTEMPT_ID; \(functionPrefix)_attempt_registration_retry=0; while :; do \(functionPrefix)_register_attempt; \(functionPrefix)_attempt_registration_status=$?; if [ \"$\(functionPrefix)_attempt_registration_status\" -eq 0 ]; then return 0; fi; \(functionPrefix)_attempt_registration_retry=$((\(functionPrefix)_attempt_registration_retry + 1)); if [ \"$\(functionPrefix)_attempt_registration_retry\" -ge 3 ]; then if [ \"$\(functionPrefix)_attempt_registration_status\" -eq \(SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue) ]; then \(functionPrefix)_registration_timed_out=1; fi; return \"$\(functionPrefix)_attempt_registration_status\"; fi; /bin/sleep 0.1; done; }",
        ]
    }

    /// Builds shell lines that retry PTY attachment and optional foreground authentication.
    ///
    /// The surrounding script supplies `hmux_ssh_attach_foreground_auth` when
    /// `reauthenticates` is true and installs `hmux_ssh_attach_signal_exit`
    /// before these lines execute.
    ///
    /// - Parameters:
    ///   - command: Shell command that performs one PTY attachment attempt.
    ///   - reauthenticates: Whether status 255 requires foreground authentication before reattaching.
    ///   - initialAuthentication: Whether the wrapper owns the initial foreground authentication
    ///     phase before its first attach. Compatibility callers that authenticate outside the
    ///     generated loop can disable this while retaining reauthentication after a later loss.
    /// - Returns: macOS `/bin/sh` lines implementing the shared retry state machine.
    public func lines(
        command: String,
        reauthenticates: Bool,
        initialAuthentication: Bool = true
    ) -> [String] {
        let reauthenticate = reauthenticates ? "hmux_ssh_attach_reauth_required=1" : ":"
        let authPolicy = SSHForegroundAuthenticationRetryPolicy()
        let authenticationResult = authPolicy.persistentAuthenticationResultShellLine(
            variablePrefix: "hmux_ssh_attach",
            terminalFailureCommand: "exit \"$hmux_ssh_attach_status\""
        )
        let backoffBuilder = SSHRetryBackoffScriptBuilder(context: .attach)
        let initialReauthentication = reauthenticates && initialAuthentication ? 1 : 0
        let noProgressPolicy = SSHPTYAttachExitCode.noProgressShellPolicy()
        let retryStatusFormat = String(
            localized: "cli.sshPtyAttach.retryStatus",
            defaultValue: "[hmux] SSH disconnected (%s); retry %s in %ss; input discarded."
        ).remoteCommandShellQuoted
        let hostUnreachableReason = String(
            localized: "cli.sshPtyAttach.retryReason.hostUnreachable",
            defaultValue: "host unreachable"
        ).remoteCommandShellQuoted
        let controlMasterReason = String(
            localized: "cli.sshPtyAttach.retryReason.controlMasterUnavailable",
            defaultValue: "SSH authentication/control unavailable"
        ).remoteCommandShellQuoted
        let daemonNotReadyReason = String(
            localized: "cli.sshPtyAttach.retryReason.daemonNotReady",
            defaultValue: "remote service is starting"
        ).remoteCommandShellQuoted
        let bridgeClosedReason = String(
            localized: "cli.sshPtyAttach.retryReason.bridgeClosed",
            defaultValue: "connection interrupted"
        ).remoteCommandShellQuoted
        let noProgressReason = String(
            localized: "cli.sshPtyAttach.retryReason.noProgress",
            defaultValue: "remote service made no progress"
        ).remoteCommandShellQuoted
        let launchAcknowledgementTimeoutReason = String(
            localized: "cli.sshPtyAttach.retryReason.launchAcknowledgementTimeout",
            defaultValue: "hmux did not acknowledge the SSH launch"
        ).remoteCommandShellQuoted
        let launchAcknowledgementTimeoutLimitFormat = String(
            localized: "cli.sshPtyAttach.launchAcknowledgementTimeoutLimitReached",
            defaultValue: "[hmux] SSH pane could not contact hmux to start the remote session after %s attempts; reconnect to try again."
        ).remoteCommandShellQuoted
        let reconnectedFormat = String(
            localized: "cli.sshPtyAttach.reconnected",
            defaultValue: "[hmux] remote PTY reconnected (attempt %s/%s)."
        ).remoteCommandShellQuoted
        let retryWithoutReauthenticationStatus =
            SSHPTYAttachExitCode.retryableWithoutReauthentication.rawValue
        let hostUnreachableStatus = SSHPTYAttachExitCode.hostUnreachable.rawValue
        let controlMasterUnavailableStatus = SSHPTYAttachExitCode.controlMasterUnavailable.rawValue
        let daemonNotReadyStatus = SSHPTYAttachExitCode.daemonNotReady.rawValue
        let authenticationRequiredStatus = SSHPTYAttachExitCode.authenticationRequired.rawValue
        let noProgressStatus = SSHPTYAttachExitCode.bridgeClosedWithoutProgress.rawValue
        let sessionRunningStatus = SSHPTYAttachExitCode.bridgeClosedSessionRunning.rawValue
        let transientStatus = SSHPTYAttachExitCode.retryableTransient.rawValue
        let launchAcknowledgementTimeoutStatus = SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue
        let terminalModeReset = SSHTerminalModeResetSequence().shellPrintfFormat.remoteCommandShellQuoted
        // Persisted launchers may predate the retry policy.  A missing or
        // malformed limit must fail closed to the same finite supervisor used
        // by newly generated SSH startup scripts; a well-formed larger budget
        // is honored up to the shared ceiling.
        let reconnectLimitLines = SSHReconnectBudget().limitNormalizationShellLines(
            variable: "hmux_ssh_attach_reconnect_limit"
        )
        var lines = [
            "hmux_ssh_attach_restore_terminal() { hmux_ssh_attach_flush_status=0; if [ \"${hmux_ssh_attach_input_paused:-0}\" = 1 ] && [ -n \"${hmux_ssh_attach_cli:-}\" ]; then \"$hmux_ssh_attach_cli\" __ssh-pty-flush-input <&0 >/dev/null 2>&1; hmux_ssh_attach_flush_status=$?; fi; hmux_ssh_attach_restore_status=0; if [ -n \"${hmux_ssh_attach_terminal_state:-}\" ]; then /bin/stty \"$hmux_ssh_attach_terminal_state\" <&0 2>/dev/null; hmux_ssh_attach_restore_status=$?; fi; hmux_ssh_attach_input_paused=0; if [ \"$hmux_ssh_attach_flush_status\" -ne 0 ] || [ \"$hmux_ssh_attach_restore_status\" -ne 0 ]; then hmux_ssh_attach_terminal_control_failed=1; fi; }",
        ]
        lines.append(contentsOf: reconnectLimitLines)
        lines.append(contentsOf: [
            "hmux_ssh_attach_reconnect_delay=\"${HMUX_SSH_RECONNECT_DELAY_SECONDS:-2}\"",
            "case \"$hmux_ssh_attach_reconnect_delay\" in ''|*[!0-9]*|0*) hmux_ssh_attach_reconnect_delay=2 ;; esac",
            "hmux_ssh_attach_reconnect_max_delay=\"${HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS:-30}\"",
            "case \"$hmux_ssh_attach_reconnect_max_delay\" in ''|*[!0-9]*|0*) hmux_ssh_attach_reconnect_max_delay=30 ;; esac",
            "if [ \"$hmux_ssh_attach_reconnect_delay\" -gt \"$hmux_ssh_attach_reconnect_max_delay\" ]; then hmux_ssh_attach_reconnect_delay=\"$hmux_ssh_attach_reconnect_max_delay\"; fi",
            "hmux_ssh_attach_reconnect_initial_delay=\"$hmux_ssh_attach_reconnect_delay\"",
            "hmux_ssh_attach_retry_reason=\(bridgeClosedReason)",
            "hmux_ssh_attach_suppress_replay=0",
        ])
        lines.append(contentsOf: noProgressPolicy.configurationLines)
        lines.append(contentsOf: [
            "hmux_ssh_attach_no_progress_retry=0",
            "hmux_ssh_attach_retry=0",
            "hmux_ssh_attach_auth_retry=0",
            "hmux_ssh_attach_auth_retry_limit=\(authPolicy.maximumConsecutiveTransientFailures)",
            "hmux_ssh_attach_auth_succeeded=0",
            "hmux_ssh_attach_reauth_required=\(initialReauthentication)",
            "hmux_ssh_attach_auth_launching=0",
            "hmux_ssh_attach_auth_event_token=",
            "HMUX_SSH_PTY_ATTACH_MANAGED_RECONNECT=1",
            "export HMUX_SSH_PTY_ATTACH_MANAGED_RECONNECT",
        ])
        lines.append(contentsOf: backoffBuilder.stateInitializationLines)
        // Host/daemon phases defer foreground auth after a known successful
        // authentication; explicit auth/control failures still take the auth
        // path, preventing credentialed sessions from silently wedging.
        lines.append(contentsOf: [
            "hmux_ssh_attach_generate_auth_event_token() {",
            "  hmux_ssh_attach_auth_event_token=",
            "  if [ -x /usr/bin/uuidgen ]; then hmux_ssh_attach_auth_event_token=$(/usr/bin/uuidgen 2>/dev/null | /usr/bin/tr '[:upper:]' '[:lower:]' || true); fi",
            "  case \"$hmux_ssh_attach_auth_event_token\" in ''|*[!A-Za-z0-9_-]*) hmux_ssh_attach_auth_event_token= ;; esac",
            "  if [ -z \"$hmux_ssh_attach_auth_event_token\" ] && [ -r /dev/urandom ] && [ -x /usr/bin/od ] && [ -x /usr/bin/tr ]; then hmux_ssh_attach_auth_event_token=$(/usr/bin/od -An -N16 -tx1 /dev/urandom 2>/dev/null | /usr/bin/tr -d '[:space:]' || true); fi",
            "  case \"$hmux_ssh_attach_auth_event_token\" in ''|*[!A-Za-z0-9_-]*) hmux_ssh_attach_auth_event_token= ;; esac",
            "}",
            "while :; do",
            "  if [ \"$hmux_ssh_attach_reauth_required\" -eq 1 ]; then",
            "    hmux_ssh_attach_auth_launching=1",
            "    hmux_ssh_attach_generate_auth_event_token",
            "    HMUX_SSH_AUTH_EVENT_TOKEN=\"$hmux_ssh_attach_auth_event_token\"; export HMUX_SSH_AUTH_EVENT_TOKEN",
            "    ( hmux_ssh_attach_foreground_auth ) <&0 &",
            "    hmux_ssh_attach_auth_pid=$!",
            "    hmux_ssh_attach_auth_launching=0",
            "    if [ -n \"${hmux_ssh_attach_pending_signal:-}\" ]; then hmux_ssh_attach_signal_exit \"$hmux_ssh_attach_pending_signal\" \"${hmux_ssh_attach_pending_signal_name:-TERM}\"; fi",
            "    wait \"$hmux_ssh_attach_auth_pid\"; hmux_ssh_attach_status=$?; hmux_ssh_attach_auth_pid=; hmux_ssh_attach_auth_event_token=; unset HMUX_SSH_AUTH_EVENT_TOKEN",
            "    \(authenticationResult)",
            "    case \"$hmux_ssh_attach_status\" in 254) hmux_ssh_attach_retry_reason=\(hostUnreachableReason) ;; 252) hmux_ssh_attach_retry_reason=\(controlMasterReason) ;; esac",
            "  fi",
            "  if [ \"$hmux_ssh_attach_reauth_required\" -eq 0 ]; then",
            "  if [ \"$hmux_ssh_attach_retry\" -lt \"$hmux_ssh_attach_reconnect_limit\" ]; then hmux_ssh_attach_can_retry=1; else hmux_ssh_attach_can_retry=0; fi",
            "  if [ -t 2 ]; then printf '\\r\\033[2K' >&2 || true; fi",
            "  HMUX_SSH_PTY_ATTACH_MANAGED_RECONNECT=1",
            "  HMUX_SSH_PTY_ATTACH_SUPPRESS_REPLAY=\"$hmux_ssh_attach_suppress_replay\"",
            "  HMUX_SSH_PTY_ATTACH_WRAPPER_CAN_RETRY=\"$hmux_ssh_attach_can_retry\"",
            "  HMUX_SSH_PTY_ATTACH_NO_PROGRESS_RETRY=\"$hmux_ssh_attach_no_progress_retry\"",
            "  HMUX_SSH_PTY_ATTACH_NO_PROGRESS_LIMIT=\"$hmux_ssh_attach_no_progress_limit\"",
            "  export HMUX_SSH_PTY_ATTACH_MANAGED_RECONNECT HMUX_SSH_PTY_ATTACH_SUPPRESS_REPLAY HMUX_SSH_PTY_ATTACH_WRAPPER_CAN_RETRY HMUX_SSH_PTY_ATTACH_NO_PROGRESS_RETRY HMUX_SSH_PTY_ATTACH_NO_PROGRESS_LIMIT",
            "  \(command)",
            "  hmux_ssh_attach_status=$?",
            "  if [ \"$hmux_ssh_attach_status\" -ne 0 ] && [ -t 2 ]; then printf \(terminalModeReset) >&2 || true; fi",
            "  if [ \"$hmux_ssh_attach_status\" -eq \(launchAcknowledgementTimeoutStatus) ] && [ \"${hmux_ssh_attach_registration_timed_out:-0}\" -ne 1 ]; then exit \"$hmux_ssh_attach_status\"; fi",
            "  if [ \"$hmux_ssh_attach_status\" -eq 0 ] && [ \"$hmux_ssh_attach_retry\" -gt 0 ] && [ -t 2 ]; then printf '\\n\\033[32m%s\\033[0m\\n' \"$(printf \(reconnectedFormat) \"$hmux_ssh_attach_retry\" \"$hmux_ssh_attach_reconnect_limit\")\" >&2 || true; fi",
            "  case \"$hmux_ssh_attach_status\" in",
            "    \(hostUnreachableStatus)) hmux_ssh_attach_retry_reason=\(hostUnreachableReason); hmux_ssh_attach_no_progress_retry=0; if [ \"$hmux_ssh_attach_auth_succeeded\" -eq 0 ]; then \(reauthenticate); fi ;;",
            "    \(controlMasterUnavailableStatus)) hmux_ssh_attach_retry_reason=\(controlMasterReason); hmux_ssh_attach_no_progress_retry=0; \(reauthenticate) ;;",
            "    \(daemonNotReadyStatus)) hmux_ssh_attach_retry_reason=\(daemonNotReadyReason); hmux_ssh_attach_no_progress_retry=0; if [ \"$hmux_ssh_attach_auth_succeeded\" -eq 0 ]; then \(reauthenticate); fi ;;",
            "    \(authenticationRequiredStatus)) hmux_ssh_attach_retry_reason=\(controlMasterReason); hmux_ssh_attach_no_progress_retry=0; \(reauthenticate) ;;",
            "    \(noProgressStatus)) hmux_ssh_attach_retry_reason=\(noProgressReason); hmux_ssh_attach_no_progress_retry=$((hmux_ssh_attach_no_progress_retry + 1)); hmux_ssh_attach_reconnect_delay=\"$hmux_ssh_attach_reconnect_initial_delay\"; \(noProgressPolicy.limitReachedCommand) ;;",
            "    \(retryWithoutReauthenticationStatus)) hmux_ssh_attach_retry_reason=\(daemonNotReadyReason); hmux_ssh_attach_no_progress_retry=0 ;;",
            "    \(sessionRunningStatus)) hmux_ssh_attach_retry_reason=\(bridgeClosedReason); hmux_ssh_attach_no_progress_retry=0; hmux_ssh_attach_reconnect_delay=\"$hmux_ssh_attach_reconnect_initial_delay\" ;;",
            "    \(transientStatus)) hmux_ssh_attach_retry_reason=\(bridgeClosedReason); hmux_ssh_attach_no_progress_retry=0; \(reauthenticate) ;;",
            "    \(launchAcknowledgementTimeoutStatus)) hmux_ssh_attach_retry_reason=\(launchAcknowledgementTimeoutReason); hmux_ssh_attach_no_progress_retry=0 ;;",
            "    *) exit \"$hmux_ssh_attach_status\" ;;",
            "  esac",
            "  fi",
            "  if [ \"$hmux_ssh_attach_retry\" -ge \"$hmux_ssh_attach_reconnect_limit\" ]; then if [ \"$hmux_ssh_attach_status\" -eq \(launchAcknowledgementTimeoutStatus) ]; then printf '\\n\\033[31m%s\\033[0m\\n' \"$(printf \(launchAcknowledgementTimeoutLimitFormat) \"$hmux_ssh_attach_reconnect_limit\")\" >&2 || true; fi; exit \"$hmux_ssh_attach_status\"; fi",
            "  hmux_ssh_attach_retry=$((hmux_ssh_attach_retry + 1))",
            "  if [ \"$hmux_ssh_attach_retry\" -gt 0 ]; then hmux_ssh_attach_suppress_replay=1; fi",
            "  \(backoffBuilder.terminalInputModeResetLine)",
            "  if [ -t 2 ]; then printf '\\033[33m%s\\033[0m' \"$(printf \(retryStatusFormat) \"$hmux_ssh_attach_retry_reason\" \"$hmux_ssh_attach_retry\" \"$hmux_ssh_attach_reconnect_delay\")\" >&2 || true; fi",
        ])
        lines.append(contentsOf: backoffBuilder.waitLines)
        lines.append(contentsOf: [
            "  if [ \"$hmux_ssh_attach_reconnect_delay\" -lt \"$hmux_ssh_attach_reconnect_max_delay\" ]; then hmux_ssh_attach_reconnect_delay=$((hmux_ssh_attach_reconnect_delay * 2)); if [ \"$hmux_ssh_attach_reconnect_delay\" -gt \"$hmux_ssh_attach_reconnect_max_delay\" ]; then hmux_ssh_attach_reconnect_delay=\"$hmux_ssh_attach_reconnect_max_delay\"; fi; fi",
            "done",
        ])
        return lines
    }
}
