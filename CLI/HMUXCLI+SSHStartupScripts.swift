import HmuxFoundation
import Foundation

extension HMUXCLI {
    func buildSSHStartupCommand(
        sshCommand: String,
        shellFeatures: String,
        remoteRelayPort: Int,
        isShellSnippet: Bool = false,
        passwordCredential: String? = nil,
        controlPathPreflightShellFunction: String? = nil,
        reconnectLimitDefault: Int = 20,
        launchScripts: SSHStartupLaunchScripts
    ) throws -> String {
        let script = buildSSHStartupScriptBody(
            sshCommand: sshCommand,
            shellFeatures: shellFeatures,
            remoteRelayPort: remoteRelayPort,
            isShellSnippet: isShellSnippet,
            passwordCredential: passwordCredential,
            controlPathPreflightShellFunction: controlPathPreflightShellFunction,
            oneTimeCommand: nil,
            reconnectLimitDefault: reconnectLimitDefault
        )
        return try writeSSHStartupScript(script, remoteRelayPort: remoteRelayPort, launchScripts: launchScripts)
    }

    func buildReusableSSHStartupCommand(
        sshCommand: String,
        shellFeatures: String,
        remoteRelayPort: Int,
        isShellSnippet: Bool = false,
        passwordCredential: String? = nil,
        controlPathPreflightShellFunction: String? = nil,
        oneTimeCommand: String? = nil,
        reconnectLimitDefault: Int = 20
    ) -> String {
        // Reusable commands are persisted in workspace metadata and can be emitted over the socket API.
        // Short-lived credentials must stay in the one-shot launcher path only.
        let script = buildSSHStartupScriptBody(
            sshCommand: sshCommand,
            shellFeatures: shellFeatures,
            remoteRelayPort: remoteRelayPort,
            isShellSnippet: isShellSnippet,
            passwordCredential: nil,
            controlPathPreflightShellFunction: controlPathPreflightShellFunction,
            oneTimeCommand: oneTimeCommand,
            reconnectLimitDefault: reconnectLimitDefault
        )
        return reusableShellStartupCommand(
            scriptBody: script,
            tempPrefix: "hmux-ssh-startup"
        )
    }

    func sshAskpassExecShellScript(passwordCredential: String) -> String {
        let passwordB64 = Data(passwordCredential.utf8).base64EncodedString()
        return [
            "set -e",
            "hmux_ssh_askpass_dir=$(mktemp -d \"${TMPDIR:-/tmp}/hmux-ssh-askpass.XXXXXX\")",
            "hmux_ssh_askpass_file=\"$hmux_ssh_askpass_dir/password\"",
            "hmux_ssh_askpass_script=\"$hmux_ssh_askpass_dir/askpass\"",
            "hmux_ssh_expect_script=\"$hmux_ssh_askpass_dir/ssh-password.exp\"",
            "cleanup() { rm -rf \"$hmux_ssh_askpass_dir\"; }",
            "trap cleanup EXIT HUP INT TERM",
            "printf %s \(shellQuote(passwordB64)) | base64 -d > \"$hmux_ssh_askpass_file\" 2>/dev/null || printf %s \(shellQuote(passwordB64)) | base64 -D > \"$hmux_ssh_askpass_file\"",
            "chmod 600 \"$hmux_ssh_askpass_file\"",
            "if command -v expect >/dev/null 2>&1; then",
            "  cat > \"$hmux_ssh_expect_script\" <<'HMUX_EXPECT'",
            "set timeout 12",
            "set password_file $env(HMUX_SSH_ASKPASS_FILE)",
            "set fh [open $password_file r]",
            "set password [read $fh]",
            "close $fh",
            "set password [string trimright $password \"\\r\\n\"]",
            "set hmux_interactive_stdin [expr {[catch {exec /bin/sh -c {test -t 0}}] == 0}]",
            "log_user 0",
            "spawn {*}$argv",
            "proc hmux_rejected_password {} {",
            "  puts stderr {\\n[hmux] Cloud VM SSH credential was rejected; reconnecting.}",
            "  catch {close}",
            "  catch {wait}",
            "  exit 255",
            "}",
            "proc hmux_relay_session {} {",
            "  global hmux_interactive_stdin",
            "  set timeout -1",
            "  log_user 1",
            "  if {$hmux_interactive_stdin} {",
            "    interact",
            "    set status [wait]",
            "    exit [lindex $status 3]",
            "  }",
            "  expect { eof { set status [wait]; exit [lindex $status 3] } }",
            "}",
            "proc hmux_wait_after_password {} {",
            "  set timeout 2",
            "  expect {",
            "    -re \"(?i)permission denied\" { hmux_rejected_password }",
            "    -re \"(?i)password:\" { hmux_rejected_password }",
            "    timeout {",
            "      set hmux_buffer \"\"",
            "      catch { set hmux_buffer $expect_out(buffer) }",
            "      if {[regexp -nocase {(password:|permission denied)} $hmux_buffer]} { hmux_rejected_password }",
            "      if {[string length $hmux_buffer] > 0} { send_user -- $hmux_buffer }",
            "      hmux_relay_session",
            "    }",
            // A session that authenticates and ends inside this window still
            // owes the user its output: flush what expect buffered before exiting.
            "    eof {",
            "      catch { send_user -- $expect_out(buffer) }",
            "      set status [wait]",
            "      exit [lindex $status 3]",
            "    }",
            "  }",
            "}",
            "expect {",
            "  -re \"(?i)password:\" {",
            "    send -- \"$password\\r\"",
            "    hmux_wait_after_password",
            "  }",
            "  timeout {",
            "    puts stderr {\\n[hmux] Cloud VM SSH credential prompt timed out; reconnecting.}",
            "    exit 255",
            "  }",
            "  eof { set status [wait]; exit [lindex $status 3] }",
            "}",
            "set status [wait]",
            "exit [lindex $status 3]",
            "HMUX_EXPECT",
            "  chmod 700 \"$hmux_ssh_expect_script\"",
            "  export HMUX_SSH_ASKPASS_FILE=\"$hmux_ssh_askpass_file\"",
            "  set +e",
            "  expect \"$hmux_ssh_expect_script\" \"$@\"",
            "  hmux_ssh_status=$?",
            "  exit \"$hmux_ssh_status\"",
            "fi",
            "printf '%s\\n' '#!/bin/sh' 'cat \"$HMUX_SSH_ASKPASS_FILE\"' > \"$hmux_ssh_askpass_script\"",
            "chmod 700 \"$hmux_ssh_askpass_script\"",
            "export HMUX_SSH_ASKPASS_FILE=\"$hmux_ssh_askpass_file\"",
            "export SSH_ASKPASS=\"$hmux_ssh_askpass_script\"",
            "export SSH_ASKPASS_REQUIRE=force",
            "export DISPLAY=\"${DISPLAY:-hmux}\"",
            "set +e",
            "\"$@\"",
            "hmux_ssh_status=$?",
            "exit \"$hmux_ssh_status\"",
        ].joined(separator: "\n")
    }
    func sshAskpassExecShellScript(passwordFilePath: String, cleanupDirectory: String) -> String {
        [
            "set -e",
            "hmux_ssh_askpass_dir=\(shellQuote(cleanupDirectory))",
            "hmux_ssh_askpass_file=\(shellQuote(passwordFilePath))",
            "hmux_ssh_askpass_script=\"$hmux_ssh_askpass_dir/askpass\"",
            "hmux_ssh_expect_script=\"$hmux_ssh_askpass_dir/ssh-password.exp\"",
            "cleanup() { rm -rf \"$hmux_ssh_askpass_dir\"; }",
            "trap cleanup EXIT HUP INT TERM",
            "chmod 600 \"$hmux_ssh_askpass_file\"",
            "if command -v expect >/dev/null 2>&1; then",
            "  cat > \"$hmux_ssh_expect_script\" <<'HMUX_EXPECT'",
            "set timeout 12",
            "set password_file $env(HMUX_SSH_ASKPASS_FILE)",
            "set fh [open $password_file r]",
            "set password [read $fh]",
            "close $fh",
            "set password [string trimright $password \"\\r\\n\"]",
            "set hmux_interactive_stdin [expr {[catch {exec /bin/sh -c {test -t 0}}] == 0}]",
            "log_user 0",
            "spawn {*}$argv",
            "proc hmux_rejected_password {} {",
            "  puts stderr {\\n[hmux] Cloud VM SSH credential was rejected; reconnecting.}",
            "  catch {close}",
            "  catch {wait}",
            "  exit 255",
            "}",
            "proc hmux_relay_session {} {",
            "  global hmux_interactive_stdin",
            "  set timeout -1",
            "  log_user 1",
            "  if {$hmux_interactive_stdin} {",
            "    interact",
            "    set status [wait]",
            "    exit [lindex $status 3]",
            "  }",
            "  expect { eof { set status [wait]; exit [lindex $status 3] } }",
            "}",
            "proc hmux_wait_after_password {} {",
            "  set timeout 2",
            "  expect {",
            "    -re \"(?i)permission denied\" { hmux_rejected_password }",
            "    -re \"(?i)password:\" { hmux_rejected_password }",
            "    timeout {",
            "      set hmux_buffer \"\"",
            "      catch { set hmux_buffer $expect_out(buffer) }",
            "      if {[regexp -nocase {(password:|permission denied)} $hmux_buffer]} { hmux_rejected_password }",
            "      if {[string length $hmux_buffer] > 0} { send_user -- $hmux_buffer }",
            "      hmux_relay_session",
            "    }",
            // A session that authenticates and ends inside this window still
            // owes the user its output: flush what expect buffered before exiting.
            "    eof {",
            "      catch { send_user -- $expect_out(buffer) }",
            "      set status [wait]",
            "      exit [lindex $status 3]",
            "    }",
            "  }",
            "}",
            "expect {",
            "  -re \"(?i)password:\" {",
            "    send -- \"$password\\r\"",
            "    hmux_wait_after_password",
            "  }",
            "  timeout {",
            "    puts stderr {\\n[hmux] Cloud VM SSH credential prompt timed out; reconnecting.}",
            "    exit 255",
            "  }",
            "  eof { set status [wait]; exit [lindex $status 3] }",
            "}",
            "set status [wait]",
            "exit [lindex $status 3]",
            "HMUX_EXPECT",
            "  chmod 700 \"$hmux_ssh_expect_script\"",
            "  export HMUX_SSH_ASKPASS_FILE=\"$hmux_ssh_askpass_file\"",
            "  set +e",
            "  expect \"$hmux_ssh_expect_script\" \"$@\"",
            "  hmux_ssh_status=$?",
            "  exit \"$hmux_ssh_status\"",
            "fi",
            "printf '%s\\n' '#!/bin/sh' 'cat \"$HMUX_SSH_ASKPASS_FILE\"' > \"$hmux_ssh_askpass_script\"",
            "chmod 700 \"$hmux_ssh_askpass_script\"",
            "export HMUX_SSH_ASKPASS_FILE=\"$hmux_ssh_askpass_file\"",
            "export SSH_ASKPASS=\"$hmux_ssh_askpass_script\"",
            "export SSH_ASKPASS_REQUIRE=force",
            "export DISPLAY=\"${DISPLAY:-hmux}\"",
            "set +e",
            "\"$@\"",
            "hmux_ssh_status=$?",
            "exit \"$hmux_ssh_status\"",
        ].joined(separator: "\n")
    }
    private func buildSSHStartupScriptBody(
        sshCommand: String,
        shellFeatures: String,
        remoteRelayPort: Int,
        isShellSnippet: Bool,
        passwordCredential: String?,
        controlPathPreflightShellFunction: String?,
        oneTimeCommand: String?,
        reconnectLimitDefault: Int
    ) -> String {
        let trimmedFeatures = shellFeatures.trimmingCharacters(in: .whitespacesAndNewlines)
        let shellFeaturesBootstrap: String = trimmedFeatures.isEmpty
            ? ""
            : "export GHOSTTY_SHELL_FEATURES=\(shellQuote(trimmedFeatures))"
        let lifecycleCleanup = buildSSHSessionEndShellCommand(remoteRelayPort: remoteRelayPort)
        let lifecycleLaunching = remoteRelayPort > 0
            ? buildSSHTerminalSessionLaunchingShellCommand()
            : ":"
        let trimmedControlPathPreflight = controlPathPreflightShellFunction?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOneTimeCommand = oneTimeCommand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasOneTimeCommand = trimmedOneTimeCommand?.isEmpty == false
        let authRetryPolicy = SSHForegroundAuthenticationRetryPolicy()
        let authenticationResult = authRetryPolicy.persistentAuthenticationResultShellLine(
            variablePrefix: "hmux_ssh",
            terminalFailureCommand: "break"
        )
        let backoffBuilder = SSHRetryBackoffScriptBuilder(context: .startup)
        let terminalModeReset = shellQuote(SSHTerminalModeResetSequence().shellPrintfFormat)
        let reconnectNote = shellQuote(sshAutoReconnectNoteFormat())
        let terminalExitPrompt = shellQuote(sshTerminalExitPromptFormat())
        let reconnectRecoveredNote = shellQuote(sshAutoReconnectRecoveredNoteFormat())
        let launchAcknowledgementTimeoutNote = shellQuote(String(
            localized: "cli.sshPtyAttach.launchAcknowledgementTimeoutRetry",
            defaultValue: "[hmux] hmux did not acknowledge the SSH launch; retrying %s in %ss.",
            bundle: CLIExecutableLocator.enclosingAppBundle() ?? .main
        ))
        let terminalExitPromptCommand = [
            shellQuote(resolvedExecutableURL()?.path ?? (args.first ?? "hmux")),
            "__ssh-terminal-exit-prompt",
        ].joined(separator: " ")
        var scriptLines: [String] = []
        if !shellFeaturesBootstrap.isEmpty {
            scriptLines.append(shellFeaturesBootstrap)
        }
        if let passwordCredential, !passwordCredential.isEmpty {
            let passwordB64 = Data(passwordCredential.utf8).base64EncodedString()
            scriptLines += [
                "hmux_ssh_askpass_dir=$(mktemp -d \"${TMPDIR:-/tmp}/hmux-ssh-askpass.XXXXXX\") || exit 1",
                "hmux_ssh_askpass_file=\"$hmux_ssh_askpass_dir/password\"",
                "hmux_ssh_askpass_script=\"$hmux_ssh_askpass_dir/askpass\"",
                "printf %s \(shellQuote(passwordB64)) | base64 -d > \"$hmux_ssh_askpass_file\" 2>/dev/null || printf %s \(shellQuote(passwordB64)) | base64 -D > \"$hmux_ssh_askpass_file\" || exit 1",
                "chmod 600 \"$hmux_ssh_askpass_file\"",
                "printf '%s\\n' '#!/bin/sh' 'cat \"$HMUX_SSH_ASKPASS_FILE\"' > \"$hmux_ssh_askpass_script\"",
                "chmod 700 \"$hmux_ssh_askpass_script\"",
                "export HMUX_SSH_ASKPASS_FILE=\"$hmux_ssh_askpass_file\"",
                "export SSH_ASKPASS=\"$hmux_ssh_askpass_script\"",
                "export SSH_ASKPASS_REQUIRE=force",
                "export DISPLAY=\"${DISPLAY:-hmux}\"",
                "hmux_ssh_cleanup_password() { rm -rf \"$hmux_ssh_askpass_dir\" 2>/dev/null || true; }",
            ]
        } else {
            scriptLines.append("hmux_ssh_cleanup_password() { :; }")
        }
        if let trimmedControlPathPreflight, !trimmedControlPathPreflight.isEmpty {
            scriptLines.append(trimmedControlPathPreflight)
        }
        if let trimmedOneTimeCommand, !trimmedOneTimeCommand.isEmpty {
            scriptLines += ["hmux_ssh_foreground_auth() {", trimmedOneTimeCommand, "}"]
            scriptLines.append(authRetryPolicy.processTreeTerminationShellFunction())
        }
        let reconnectConfiguration = [
            "hmux_ssh_reconnect_limit=\"${HMUX_SSH_RECONNECT_LIMIT:-\(max(0, reconnectLimitDefault))}\"",
            "case \"$hmux_ssh_reconnect_limit\" in ''|*[!0-9]*) hmux_ssh_reconnect_limit=20 ;; esac",
            "hmux_ssh_reconnect_delay=\"${HMUX_SSH_RECONNECT_DELAY_SECONDS:-2}\"",
            "case \"$hmux_ssh_reconnect_delay\" in ''|*[!0-9]*) hmux_ssh_reconnect_delay=2 ;; esac",
            "if [ \"$hmux_ssh_reconnect_delay\" -lt 1 ]; then hmux_ssh_reconnect_delay=2; fi",
        ]
        scriptLines += [
            "rm -f -- \"$0\" 2>/dev/null || true",
            "HMUX_SSH_SESSION_ENDED=0",
            "HMUX_SSH_STARTUP_PID=$$",
            "export HMUX_SSH_STARTUP_PID",
        ]
        scriptLines += reconnectConfiguration
        scriptLines += [
            "hmux_ssh_retry=0",
            "hmux_ssh_auth_retry_limit=\(authRetryPolicy.maximumConsecutiveTransientFailures); hmux_ssh_auth_retry=0",
            "hmux_ssh_auth_succeeded=0",
            // Initial transient foreground-auth failures are a reconnect phase, so boot-time outages share this loop.
            "hmux_ssh_reauth_required=\(hasOneTimeCommand ? 1 : 0)",
            "HMUX_SSH_CHILD_PID=; HMUX_SSH_AUTH_PID=; HMUX_SSH_PENDING_SIGNAL=; HMUX_SSH_PENDING_SIGNAL_NAME=",
        ]
        scriptLines += backoffBuilder.stateInitializationLines
        scriptLines += [
            "hmux_ssh_note() { if [ -t 2 ]; then printf \"$@\" >&2 || true; fi; }",
            "hmux_ssh_reset_terminal_modes() { if [ -t 2 ]; then printf \(terminalModeReset) >&2 || true; fi; }",
            "hmux_ssh_register_attempt() { \(lifecycleLaunching); }",
        ] + SSHPTYAttachRetryScriptBuilder().launchRegistrationRetryLines(functionPrefix: "hmux_ssh") + [
            "hmux_ssh_session_end() { if [ \"${HMUX_SSH_SESSION_ENDED:-0}\" = 1 ]; then return; fi; HMUX_SSH_SESSION_ENDED=1; hmux_ssh_cleanup_password; \(lifecycleCleanup); }",
            "hmux_ssh_retire_for_signal() { hmux_ssh_signal_status=\"$1\"; HMUX_SSH_SESSION_ENDED=1; hmux_ssh_cleanup_password; trap - EXIT HUP INT TERM; exit \"$hmux_ssh_signal_status\"; }",
            "hmux_ssh_signal_exit() { hmux_ssh_signal_status=\"$1\"; hmux_ssh_signal_name=\"$2\"; if [ -n \"${HMUX_SSH_AUTH_PID:-}\" ]; then hmux_ssh_terminate_auth_process_tree \"$HMUX_SSH_AUTH_PID\" \"$HMUX_SSH_STARTUP_PID\"; wait \"$HMUX_SSH_AUTH_PID\" 2>/dev/null || true; HMUX_SSH_AUTH_PID=; \(backoffBuilder.signalHandlerBranches) elif [ -z \"${HMUX_SSH_CHILD_PID:-}\" ]; then HMUX_SSH_PENDING_SIGNAL=\"$hmux_ssh_signal_status\"; HMUX_SSH_PENDING_SIGNAL_NAME=\"$hmux_ssh_signal_name\"; return; fi; hmux_ssh_retire_for_signal \"$hmux_ssh_signal_status\"; }",
            "trap 'hmux_ssh_session_end' EXIT",
            "trap 'hmux_ssh_signal_exit 129 HUP' HUP",
            "trap 'hmux_ssh_signal_exit 130 INT' INT",
            "trap 'hmux_ssh_signal_exit 143 TERM' TERM",
        ]
        scriptLines += [
            "while :; do",
            "  if [ -n \"${HMUX_SSH_PENDING_SIGNAL:-}\" ]; then hmux_ssh_retire_for_signal \"$HMUX_SSH_PENDING_SIGNAL\"; fi",
        ]
        if hasOneTimeCommand {
            scriptLines.append("  if [ \"$hmux_ssh_reauth_required\" -eq 1 ]; then")
            scriptLines += ["    ( hmux_ssh_foreground_auth ) <&0 &", "    HMUX_SSH_AUTH_PID=$!; if [ -n \"${HMUX_SSH_PENDING_SIGNAL:-}\" ]; then hmux_ssh_signal_exit \"$HMUX_SSH_PENDING_SIGNAL\" \"${HMUX_SSH_PENDING_SIGNAL_NAME:-TERM}\"; fi; wait \"$HMUX_SSH_AUTH_PID\"; hmux_ssh_status=$?; HMUX_SSH_AUTH_PID=; case \"$hmux_ssh_status\" in 129|130|143) hmux_ssh_retire_for_signal \"$hmux_ssh_status\" ;; esac; if [ -n \"${HMUX_SSH_PENDING_SIGNAL:-}\" ]; then hmux_ssh_session_end; trap - EXIT HUP INT TERM; exit \"$HMUX_SSH_PENDING_SIGNAL\"; fi", "    \(authenticationResult)", "  fi", "  if [ \"$hmux_ssh_reauth_required\" -eq 0 ]; then"]
        }
        if let trimmedControlPathPreflight, !trimmedControlPathPreflight.isEmpty,
           !hasOneTimeCommand {
            scriptLines.append("  hmux_ssh_preflight_control_path")
        }
        scriptLines += [
            "  hmux_ssh_begin_attempt",
            "  hmux_ssh_registration_status=$?",
            "  if [ \"$hmux_ssh_registration_status\" -ne 0 ] && [ \"$hmux_ssh_registration_status\" -ne \(SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue) ]; then exit \"$hmux_ssh_registration_status\"; fi",
            "  if [ -n \"${HMUX_SSH_PENDING_SIGNAL:-}\" ]; then hmux_ssh_retire_for_signal \"$HMUX_SSH_PENDING_SIGNAL\"; fi",
        ]
        if isShellSnippet {
            scriptLines += [
                "  if [ \"$hmux_ssh_registration_status\" -eq 0 ]; then",
                "    (",
                "      \(sshCommand)",
                "    ) <&0 &",
                "  fi",
            ]
        } else {
            scriptLines += [
                "  if [ \"$hmux_ssh_registration_status\" -eq 0 ]; then",
                "    command \(sshCommand) <&0 &",
                "  fi",
            ]
        }
        scriptLines += [
            "  HMUX_SSH_CHILD_PID=",
            "  if [ \"$hmux_ssh_registration_status\" -eq 0 ]; then HMUX_SSH_CHILD_PID=$!; fi",
            "  if [ -n \"${HMUX_SSH_PENDING_SIGNAL:-}\" ]; then hmux_ssh_signal_exit \"$HMUX_SSH_PENDING_SIGNAL\"; fi",
            "  if [ \"$hmux_ssh_registration_status\" -eq 0 ]; then wait \"$HMUX_SSH_CHILD_PID\"; hmux_ssh_status=$?; else hmux_ssh_status=\"$hmux_ssh_registration_status\"; fi",
            "  HMUX_SSH_CHILD_PID=",
            "  if [ \"$hmux_ssh_status\" -eq \(SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue) ] && [ \"$hmux_ssh_registration_status\" -eq 0 ]; then break; fi",
            "  if [ \"$hmux_ssh_status\" -eq 0 ]; then if [ \"$hmux_ssh_retry\" -gt 0 ]; then hmux_ssh_note \"$(printf \(reconnectRecoveredNote) \"$hmux_ssh_retry\" \"$hmux_ssh_reconnect_limit\")\"; fi; break; fi",
            "  hmux_ssh_reset_terminal_modes",
            "  case \"$hmux_ssh_status\" in 255|\(SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue)) ;; *) break ;; esac",
        ]
        if hasOneTimeCommand {
            scriptLines += ["  if [ \"$hmux_ssh_status\" -eq 255 ]; then hmux_ssh_reauth_required=1; fi", "  fi"]
        }
        let retryLimitCondition =
            "  if [ \"$hmux_ssh_retry\" -ge \"$hmux_ssh_reconnect_limit\" ]; then break; fi"
        scriptLines.append(retryLimitCondition)
        scriptLines += [
            "  hmux_ssh_retry=$((hmux_ssh_retry + 1))",
            "  \(backoffBuilder.terminalInputModeResetLine)",
            "  if [ \"$hmux_ssh_status\" -eq \(SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue) ]; then hmux_ssh_note \(launchAcknowledgementTimeoutNote) \"$hmux_ssh_retry\" \"$hmux_ssh_reconnect_delay\"; else hmux_ssh_note \(reconnectNote) \"$hmux_ssh_status\" \"$hmux_ssh_retry\" \"$hmux_ssh_reconnect_limit\"; fi",
        ]
        scriptLines += backoffBuilder.waitLines
        scriptLines += [
            "  if [ -n \"${HMUX_SSH_PENDING_SIGNAL:-}\" ]; then hmux_ssh_session_end; trap - EXIT HUP INT TERM; exit \"$HMUX_SSH_PENDING_SIGNAL\"; fi",
            "done",
            "trap - EXIT HUP INT TERM",
            "hmux_ssh_session_end",
            "if [ \"$hmux_ssh_status\" -ne 0 ]; then",
            "  \(backoffBuilder.terminalInputModeResetLine)",
            "  hmux_ssh_prompt_tty_state=$(/bin/stty -g <&0 2>/dev/null || true)",
            "  hmux_ssh_prompt_restore_tty() { if [ -n \"${hmux_ssh_prompt_tty_state:-}\" ]; then /bin/stty \"$hmux_ssh_prompt_tty_state\" <&0 2>/dev/null || true; hmux_ssh_prompt_tty_state=; fi; }",
            "  hmux_ssh_prompt_signal_exit() { hmux_ssh_prompt_signal_status=\"$1\"; hmux_ssh_prompt_restore_tty; trap - EXIT HUP INT TERM; exit \"$hmux_ssh_prompt_signal_status\"; }",
            "  trap 'hmux_ssh_prompt_restore_tty' EXIT",
            "  trap 'hmux_ssh_prompt_signal_exit 129' HUP",
            "  trap 'hmux_ssh_prompt_signal_exit 130' INT",
            "  trap 'hmux_ssh_prompt_signal_exit 143' TERM",
            "  printf \(terminalExitPrompt) \"$hmux_ssh_status\" >&2 || true",
            "  if [ -t 0 ]; then \(terminalExitPromptCommand) <&0; else exec \(terminalExitPromptCommand) <&0; fi",
            "  hmux_ssh_prompt_restore_tty",
            "  trap - EXIT HUP INT TERM",
            "fi",
            "exit $hmux_ssh_status",
        ]
        return scriptLines.joined(separator: "\n")
    }
    private func writeSSHStartupScript(
        _ scriptBody: String,
        remoteRelayPort: Int,
        launchScripts: SSHStartupLaunchScripts
    ) throws -> String {
        let scriptURL = try launchScripts.write(scriptBody: scriptBody, remoteRelayPort: remoteRelayPort)
        return shellQuote(scriptURL.path)
    }
    private func reusableShellStartupCommand(
        scriptBody: String,
        tempPrefix: String
    ) -> String {
        let fullScript = "#!/bin/sh\n\(scriptBody)\n"
        let encodedScript = Data(fullScript.utf8).base64EncodedString()
        let encodedLiteral = shellQuote(encodedScript)
        let wrapper = [
            "hmux_tmp=$(mktemp \"${TMPDIR:-/tmp}/\(tempPrefix).XXXXXX\") || exit 1",
            "hmux_cleanup() { rm -f -- \"$hmux_tmp\" 2>/dev/null || true; }",
            "trap 'hmux_cleanup' EXIT HUP INT TERM",
            // Choose the decoder before writing the payload. Repeating the large
            // bootstrap for a fallback can push the launcher past macOS ARG_MAX.
            "if base64 -d </dev/null >/dev/null 2>&1; then hmux_decode_flag=-d; else hmux_decode_flag=-D; fi",
            "(printf %s \(encodedLiteral) | base64 \"$hmux_decode_flag\") > \"$hmux_tmp\" || exit 1",
            "chmod 700 \"$hmux_tmp\" >/dev/null 2>&1 || true",
            "/bin/sh \"$hmux_tmp\"",
            "hmux_status=$?",
            "trap - EXIT HUP INT TERM",
            "hmux_cleanup",
            "unset hmux_tmp hmux_decode_flag",
            "unset -f hmux_cleanup 2>/dev/null || true",
            "exit $hmux_status",
        ].joined(separator: "\n")
        return "/bin/sh -c \(shellQuote(wrapper))"
    }
    private func buildSSHSessionEndShellCommand(remoteRelayPort: Int) -> String {
        [
            "if [ -n \"${HMUX_BUNDLED_CLI_PATH:-}\" ]",
            "&& [ -x \"${HMUX_BUNDLED_CLI_PATH}\" ]",
            "&& [ -n \"${HMUX_SOCKET_PATH:-}\" ]",
            "&& [ -n \"${HMUX_WORKSPACE_ID:-}\" ]",
            "&& [ -n \"${HMUX_SURFACE_ID:-}\" ]; then",
            "\"${HMUX_BUNDLED_CLI_PATH}\" --socket \"${HMUX_SOCKET_PATH}\" ssh-session-end --relay-port \(remoteRelayPort) --workspace \"${HMUX_WORKSPACE_ID}\" --surface \"${HMUX_SURFACE_ID}\" --terminal-lifecycle-id \"${HMUX_TERMINAL_LIFECYCLE_ID:-}\" --session-id \"${HMUX_SSH_PTY_SESSION_ID:-}\" --lifecycle-id \"${HMUX_SSH_PTY_LIFECYCLE_ID:-}\" >/dev/null 2>&1 || true;",
            "elif command -v hmux >/dev/null 2>&1",
            "&& [ -n \"${HMUX_WORKSPACE_ID:-}\" ]",
            "&& [ -n \"${HMUX_SURFACE_ID:-}\" ]; then",
            "hmux ssh-session-end --relay-port \(remoteRelayPort) --workspace \"${HMUX_WORKSPACE_ID}\" --surface \"${HMUX_SURFACE_ID}\" --terminal-lifecycle-id \"${HMUX_TERMINAL_LIFECYCLE_ID:-}\" --session-id \"${HMUX_SSH_PTY_SESSION_ID:-}\" --lifecycle-id \"${HMUX_SSH_PTY_LIFECYCLE_ID:-}\" >/dev/null 2>&1 || true;",
            "fi",
        ].joined(separator: " ")
    }

    private func buildSSHTerminalSessionLaunchingShellCommand() -> String {
        let arguments =
            "rpc workspace.remote.terminal_session_launching " +
            "\"{\\\"workspace_id\\\":\\\"${HMUX_WORKSPACE_ID}\\\"," +
            "\\\"surface_id\\\":\\\"${HMUX_SURFACE_ID}\\\"," +
            "\\\"terminal_lifecycle_id\\\":\\\"${HMUX_TERMINAL_LIFECYCLE_ID}\\\"," +
            "\\\"attempt_id\\\":\\\"${HMUX_SSH_ATTEMPT_ID}\\\"}\""
        return [
            "if [ -n \"${HMUX_BUNDLED_CLI_PATH:-}\" ]",
            "&& [ -x \"${HMUX_BUNDLED_CLI_PATH}\" ]",
            "&& [ -n \"${HMUX_SOCKET_PATH:-}\" ]",
            "&& [ -n \"${HMUX_WORKSPACE_ID:-}\" ]",
            "&& [ -n \"${HMUX_SURFACE_ID:-}\" ]; then",
            "HMUXTERM_CLI_RESPONSE_TIMEOUT_SEC=2 \"${HMUX_BUNDLED_CLI_PATH}\" --socket \"${HMUX_SOCKET_PATH}\" \(arguments) >/dev/null 2>&1;",
            "elif command -v hmux >/dev/null 2>&1",
            "&& [ -n \"${HMUX_SOCKET_PATH:-}\" ]",
            "&& [ -n \"${HMUX_WORKSPACE_ID:-}\" ]",
            "&& [ -n \"${HMUX_SURFACE_ID:-}\" ]; then",
            "HMUXTERM_CLI_RESPONSE_TIMEOUT_SEC=2 hmux --socket \"${HMUX_SOCKET_PATH}\" \(arguments) >/dev/null 2>&1;",
            "else",
            "false;",
            "fi",
        ].joined(separator: " ")
    }
}
