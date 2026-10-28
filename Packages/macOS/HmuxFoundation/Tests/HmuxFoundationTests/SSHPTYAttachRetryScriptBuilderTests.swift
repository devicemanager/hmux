import Darwin
import Foundation
import Testing

@testable import HmuxFoundation

@Suite(.serialized)
struct SSHPTYAttachRetryScriptBuilderTests {
    @Test func launchAcknowledgementTimeoutRetriesTheWholeAttachAttempt() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-launch-timeout-\(UUID().uuidString)")
        let fakeCLI = root.appendingPathComponent("hmux")
        let sleep = root.appendingPathComponent("sleep")
        let log = root.appendingPathComponent("events")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try """
            #!/bin/sh
            if [ "$3" = rpc ]; then
              count=$(cat "$HMUX_TEST_LAUNCH_COUNT" 2>/dev/null || printf 0)
              count=$((count + 1))
              printf '%s' "$count" > "$HMUX_TEST_LAUNCH_COUNT"
              if [ "$count" -le 3 ]; then exit \(SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue); fi
            fi
            exit 0
            """.write(to: fakeCLI, atomically: true, encoding: .utf8)
        try "#!/bin/sh\nexit 0\n".write(to: sleep, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLI.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sleep.path)

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_ssh_attach_attempt",
            reauthenticates: false
        )
        let registrationLines = SSHPTYAttachRetryScriptBuilder()
            .launchRegistrationRetryLines(functionPrefix: "hmux_ssh_attach")
        let script = ([
            "hmux_ssh_attach_cli=\"$HMUX_BUNDLED_CLI_PATH\"",
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "hmux_ssh_attach_register_attempt() { hmux_ssh_attach_launch_payload=payload; HMUXTERM_CLI_RESPONSE_TIMEOUT_SEC=2 \"$hmux_ssh_attach_cli\" --socket \"$HMUX_SOCKET_PATH\" rpc workspace.remote.terminal_session_launching \"$hmux_ssh_attach_launch_payload\" >/dev/null 2>&1; }",
            "hmux_ssh_attach_attempt() { hmux_ssh_attach_begin_attempt || return $?; printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"; }",
        ] + registrationLines + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "PATH": "\(root.path):/usr/bin:/bin",
                "HMUX_BUNDLED_CLI_PATH": fakeCLI.path,
                "HMUX_SOCKET_PATH": "/tmp/hmux-test.sock",
                "HMUX_WORKSPACE_ID": UUID().uuidString,
                "HMUX_SURFACE_ID": UUID().uuidString,
                "HMUX_TERMINAL_LIFECYCLE_ID": UUID().uuidString,
                "HMUX_TEST_LAUNCH_COUNT": root.appendingPathComponent("launch-count").path,
                "HMUX_TEST_LOG": log.path,
                "HMUX_SSH_RECONNECT_DELAY_SECONDS": "1",
                "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "1",
            ]
        )

        #expect(result.status == 0, Comment(rawValue: result.stderr))
        #expect(try String(contentsOf: log, encoding: .utf8) == "attach\n")
        #expect(try String(contentsOf: root.appendingPathComponent("launch-count"), encoding: .utf8) == "4")
    }

    @Test func nonTimeoutRegistrationFailureRetainsBoundedRetry() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-launch-failure-\(UUID().uuidString)")
        let fakeCLI = root.appendingPathComponent("hmux")
        let count = root.appendingPathComponent("launch-count")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "#!/bin/sh\ncount=$(cat \"$HMUX_TEST_LAUNCH_COUNT\" 2>/dev/null || printf 0)\nprintf '%s' $((count + 1)) > \"$HMUX_TEST_LAUNCH_COUNT\"\nexit 1\n"
            .write(to: fakeCLI, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLI.path)

        let registrationLines = SSHPTYAttachRetryScriptBuilder()
            .launchRegistrationRetryLines(functionPrefix: "hmux_ssh_attach")
        let script = ([
            "hmux_ssh_attach_cli=\"$HMUX_BUNDLED_CLI_PATH\"",
            "hmux_ssh_attach_register_attempt() { \"$hmux_ssh_attach_cli\" rpc workspace.remote.terminal_session_launching payload; }",
        ] + registrationLines + [
            "hmux_ssh_attach_begin_attempt",
        ]).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "HMUX_BUNDLED_CLI_PATH": fakeCLI.path,
                "HMUX_TEST_LAUNCH_COUNT": count.path,
            ]
        )

        #expect(result.status == 1, Comment(rawValue: result.stderr))
        #expect(try String(contentsOf: count, encoding: .utf8) == "3")
    }

    @Test func attachExitCodeMatchingLaunchTimeoutIsNotRetried() throws {
        let log = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-launch-status-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: log) }

        let registrationLines = SSHPTYAttachRetryScriptBuilder()
            .launchRegistrationRetryLines(functionPrefix: "hmux_ssh_attach")
        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_ssh_attach_attempt",
            reauthenticates: false
        )
        let script = ([
            "hmux_ssh_attach_register_attempt() { return 0; }",
            "hmux_ssh_attach_attempt() { hmux_ssh_attach_begin_attempt || return \"$?\"; printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"; return \(SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue); }",
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
        ] + registrationLines + retryLines).joined(separator: "\n")

        let result = try run(script, environment: ["HMUX_TEST_LOG": log.path])

        #expect(result.status == SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue)
        #expect(try String(contentsOf: log, encoding: .utf8) == "attach\n")
    }

    @Test func launchAcknowledgementTimeoutPrintsAReasonWhenBudgetEnds() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-launch-timeout-terminal-\(UUID().uuidString)")
        let fakeCLI = root.appendingPathComponent("hmux")
        let sleep = root.appendingPathComponent("sleep")
        let log = root.appendingPathComponent("events")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "#!/bin/sh\nexit \(SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue)\n".write(to: fakeCLI, atomically: true, encoding: .utf8)
        try "#!/bin/sh\nexit 0\n".write(to: sleep, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fakeCLI.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: sleep.path)

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_ssh_attach_attempt",
            reauthenticates: false
        )
        let registrationLines = SSHPTYAttachRetryScriptBuilder()
            .launchRegistrationRetryLines(functionPrefix: "hmux_ssh_attach")
        let script = ([
            "hmux_ssh_attach_cli=\"$HMUX_BUNDLED_CLI_PATH\"",
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "hmux_ssh_attach_register_attempt() { HMUXTERM_CLI_RESPONSE_TIMEOUT_SEC=2 \"$hmux_ssh_attach_cli\" --socket \"$HMUX_SOCKET_PATH\" rpc workspace.remote.terminal_session_launching payload >/dev/null 2>&1; }",
            "hmux_ssh_attach_attempt() { hmux_ssh_attach_begin_attempt || return \"$?\"; printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"; }",
        ] + registrationLines + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "PATH": "\(root.path):/usr/bin:/bin",
                "HMUX_BUNDLED_CLI_PATH": fakeCLI.path,
                "HMUX_SOCKET_PATH": "/tmp/hmux-test.sock",
                "HMUX_WORKSPACE_ID": UUID().uuidString,
                "HMUX_SSH_RECONNECT_LIMIT": "1",
                "HMUX_SSH_RECONNECT_DELAY_SECONDS": "1",
                "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "1",
                "HMUX_TEST_LOG": log.path,
            ]
        )

        #expect(result.status == SSHPTYAttachExitCode.launchAcknowledgementTimedOut.rawValue)
        #expect(result.stderr.contains("could not contact hmux to start the remote session"))
        #expect(!FileManager.default.fileExists(atPath: log.path))
    }

    @Test func defaultReconnectPolicyIsFinite() {
        let script = SSHPTYAttachRetryScriptBuilder()
            .lines(command: "hmux_test_attach", reauthenticates: false)
            .joined(separator: "\n")

        #expect(script.contains("hmux_ssh_attach_reconnect_limit=\"${HMUX_SSH_RECONNECT_LIMIT:-20}\""))
        #expect(!script.contains("hmux_ssh_attach_reconnect_limit='∞'"))
        #expect(!script.contains("hmux_ssh_attach_reconnect_unbounded=1"))
    }

    @Test func retriesInitialAuthenticationBeforeAttaching() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-retry-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: true
        )
        let script = ([
            "hmux_ssh_attach_auth_pid=",
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "sleep() { printf 'sleep:%s\\n' \"$1\" >> \"$HMUX_TEST_LOG\"; }",
            "hmux_test_attach() { printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"; return 7; }",
            "hmux_ssh_attach_foreground_auth() {",
            "  count=$(grep -c '^auth$' \"$HMUX_TEST_LOG\" 2>/dev/null) || count=0",
            "  printf '%s\\n' auth >> \"$HMUX_TEST_LOG\"",
            "  if [ \"$count\" -eq 0 ]; then return 254; fi",
            "  return 0",
            "}",
        ] + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "HMUX_TEST_LOG": logURL.path,
                "HMUX_SSH_RECONNECT_DELAY_SECONDS": "2",
                "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "2",
            ]
        )

        #expect(result.status == 7)
        #expect(try String(contentsOf: logURL, encoding: .utf8) == "auth\nsleep:2\nauth\nattach\n")
    }

    @Test func retriesAttachWithoutRequiringAuthentication() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-only-retry-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: false
        )
        let script = ([
            "sleep() { printf 'sleep:%s\\n' \"$1\" >> \"$HMUX_TEST_LOG\"; }",
            "hmux_test_attach() {",
            """
            count=$(grep -c '^attach$' "$HMUX_TEST_LOG" 2>/dev/null) || count=0
            printf '%s\\n' attach >> "$HMUX_TEST_LOG"
            if [ "$count" -eq 0 ]; then return 255; fi
            return 253
            """,
            "}",
        ] + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "HMUX_TEST_LOG": logURL.path,
                "HMUX_SSH_RECONNECT_DELAY_SECONDS": "2",
                "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "2",
            ]
        )

        #expect(result.status == 253)
        #expect(try String(contentsOf: logURL, encoding: .utf8) == "attach\nsleep:2\nattach\n")
    }

    // Regression for #9443: the loop used to prefix the attach command with env
    // assignments, which POSIX only allows before a simple command, so a compound
    // attach command made the generated hmux-ssh-startup script fail with
    // "syntax error near unexpected token `then'".
    @Test func retryLoopIsValidPOSIXShellForCompoundAttachCommands() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-compound-\(UUID().uuidString)")
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-compound-\(UUID().uuidString).sh")
        defer {
            try? FileManager.default.removeItem(at: logURL)
            try? FileManager.default.removeItem(at: scriptURL)
        }

        let compoundCommand = [
            "if [ \"$hmux_ssh_attach_no_progress_retry\" -gt 0 ]; then : || exit 1; fi",
            "printf '%s/%s/%s\\n' \"$HMUX_SSH_PTY_ATTACH_WRAPPER_CAN_RETRY\" \"$HMUX_SSH_PTY_ATTACH_NO_PROGRESS_RETRY\" \"$HMUX_SSH_PTY_ATTACH_NO_PROGRESS_LIMIT\" >> \"$HMUX_TEST_LOG\"",
            "exit 0",
        ].joined(separator: "\n")
        let script = SSHPTYAttachRetryScriptBuilder().lines(
            command: compoundCommand,
            reauthenticates: false
        ).joined(separator: "\n")
        try (script + "\n").write(to: scriptURL, atomically: true, encoding: .utf8)

        let syntaxCheck = try run("/bin/sh -n '\(scriptURL.path)'", environment: [:])
        #expect(syntaxCheck.status == 0, "\(syntaxCheck.stderr)\n\(script)")

        // The loop must still hand the retry budget to the command it runs.
        let execution = try run(
            script,
            environment: [
                "HMUX_TEST_LOG": logURL.path,
                "HMUX_SSH_RECONNECT_LIMIT": "",
                "HMUX_SSH_PTY_NO_PROGRESS_RETRY_LIMIT": "3",
            ]
        )
        #expect(execution.status == 0, "\(execution.stderr)")
        #expect(try String(contentsOf: logURL, encoding: .utf8) == "1/0/3\n")
    }

    @Test func establishedSessionStopsAfterTheFiniteReconnectBudget() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-unclassified-reauth-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: true
        )
        let script = ([
            "hmux_ssh_attach_auth_pid=",
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "sleep() { :; }",
            "hmux_test_attach() {",
            "  count=$(grep -c '^attach$' \"$HMUX_TEST_LOG\" 2>/dev/null || true)",
            "  count=${count:-0}",
            "  printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"",
            "  if [ \"$count\" -eq 0 ]; then return 255; fi",
            "  return 7",
            "}",
            "hmux_ssh_attach_foreground_auth() {",
            "  count=$(grep -c '^auth$' \"$HMUX_TEST_LOG\" 2>/dev/null) || count=0",
            "  printf '%s\\n' auth >> \"$HMUX_TEST_LOG\"",
            "  if [ \"$count\" -eq 0 ]; then return 0; fi",
            "  if [ \"$count\" -eq 1 ]; then return 252; fi",
            "  if [ \"$count\" -le 21 ]; then return 254; fi",
            "  return 0",
            "}",
        ] + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "HMUX_TEST_LOG": logURL.path,
                "HMUX_SSH_RECONNECT_DELAY_SECONDS": "2",
                "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "2",
            ]
        )

        #expect(result.status == 254)
        let events = try String(contentsOf: logURL, encoding: .utf8).split(separator: "\n")
        #expect(events.filter { $0 == "auth" }.count == 21)
        #expect(events.filter { $0 == "attach" }.count == 1)
    }

    @Test func permanentReauthenticationStillFailsClosedAfterEstablishedSession() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-permanent-reauth-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: true
        )
        let script = ([
            "hmux_ssh_attach_auth_pid=",
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "sleep() { :; }",
            "hmux_test_attach() { printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"; return 255; }",
            "hmux_ssh_attach_foreground_auth() {",
            "  count=$(grep -c '^auth$' \"$HMUX_TEST_LOG\" 2>/dev/null) || count=0",
            "  printf '%s\\n' auth >> \"$HMUX_TEST_LOG\"",
            "  if [ \"$count\" -eq 0 ]; then return 0; fi",
            "  return 255",
            "}",
        ] + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "HMUX_TEST_LOG": logURL.path,
                "HMUX_SSH_RECONNECT_DELAY_SECONDS": "2",
                "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "2",
            ]
        )

        #expect(result.status == 255)
        #expect(try String(contentsOf: logURL, encoding: .utf8) == "auth\nattach\nauth\n")
    }

    @Test(arguments: [
        (SIGHUP, Int32(129), false),
        (SIGINT, Int32(130), false),
        (SIGTERM, Int32(143), false),
        (SIGHUP, Int32(129), true),
        (SIGINT, Int32(130), true),
        (SIGTERM, Int32(143), true),
    ])
    func signalInterruptsReconnectBackoffPromptly(
        signal: Int32,
        expectedStatus: Int32,
        reauthenticates: Bool
    ) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-backoff-\(UUID().uuidString)", isDirectory: true)
        let markerURL = root.appendingPathComponent("shell-pid")
        let backoffReadyURL = root.appendingPathComponent("backoff-ready")
        let backoffSleepPIDURL = root.appendingPathComponent("backoff-sleep-pid")
        let fakeSleepURL = root.appendingPathComponent("sleep")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try """
        #!/bin/sh
        printf '%s\n' "$$" > "$HMUX_TEST_BACKOFF_SLEEP_PID"
        printf 'ready\n' > "$HMUX_TEST_BACKOFF_READY"
        exec /bin/sleep "$1"
        """.write(to: fakeSleepURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: fakeSleepURL.path
        )
        defer {
            if let rawPID = try? String(contentsOf: backoffSleepPIDURL, encoding: .utf8),
               let pid = Int32(rawPID.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Darwin.kill(pid, SIGKILL)
            }
            try? FileManager.default.removeItem(at: root)
        }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: reauthenticates
        )
        let script = ([
            "hmux_ssh_attach_cli=/bin/true",
            "hmux_ssh_attach_signal_exit() {",
            "  hmux_ssh_attach_signal_status=\"$1\"",
            "  hmux_ssh_attach_signal_name=\"$2\"",
            "  if [ -n \"${hmux_ssh_attach_backoff_pid:-}\" ]; then",
            "    kill -TERM \"$hmux_ssh_attach_backoff_pid\" >/dev/null 2>&1 || true",
            "    wait \"$hmux_ssh_attach_backoff_pid\" 2>/dev/null || true",
            "    hmux_ssh_attach_backoff_pid=",
            "  elif [ \"${hmux_ssh_attach_backoff_launching:-0}\" = 1 ]; then",
            "    hmux_ssh_attach_pending_signal=\"$hmux_ssh_attach_signal_status\"",
            "    hmux_ssh_attach_pending_signal_name=\"$hmux_ssh_attach_signal_name\"",
            "    return",
            "  fi",
            "  trap - HUP INT TERM",
            "  exit \"$hmux_ssh_attach_signal_status\"",
            "}",
            "trap 'hmux_ssh_attach_signal_exit 129 HUP' HUP",
            "trap 'hmux_ssh_attach_signal_exit 130 INT' INT",
            "trap 'hmux_ssh_attach_signal_exit 143 TERM' TERM",
            "hmux_test_attach() { printf '%s\\n' \"$$\" > \"$HMUX_TEST_BACKOFF_MARKER\"; return 255; }",
            "hmux_ssh_attach_foreground_auth() { printf '%s\\n' \"$$\" > \"$HMUX_TEST_BACKOFF_MARKER\"; return 254; }",
        ] + retryLines).joined(separator: "\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "HMUX_TEST_BACKOFF_MARKER": markerURL.path,
            "HMUX_TEST_BACKOFF_READY": backoffReadyURL.path,
            "HMUX_TEST_BACKOFF_SLEEP_PID": backoffSleepPIDURL.path,
            "PATH": "\(root.path):/usr/bin:/bin",
            "HMUX_SSH_RECONNECT_DELAY_SECONDS": "30",
            "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "30",
        ]) { _, override in override }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        let markerDeadline = Date().addingTimeInterval(3)
        while !FileManager.default.fileExists(atPath: markerURL.path),
              process.isRunning,
              Date() < markerDeadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
        #expect(
            waitForFile(
                at: backoffReadyURL,
                containing: "ready",
                while: process,
                timeout: 3
            )
        )

        let shellPID = try #require(
            Int32(
                String(contentsOf: markerURL, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        Darwin.kill(shellPID, signal)
        let exitDeadline = Date().addingTimeInterval(1)
        while process.isRunning, Date() < exitDeadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        let exitedPromptly = !process.isRunning
        if process.isRunning {
            Darwin.kill(shellPID, SIGKILL)
        }
        process.waitUntilExit()

        #expect(exitedPromptly)
        if exitedPromptly {
            #expect(process.terminationReason == .exit)
            #expect(process.terminationStatus == expectedStatus)
        }
    }

    @Test func reconnectBackoffDiscardsQueuedTerminalInput() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-queued-input-\(UUID().uuidString)")
        let backoffMarkerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-backoff-ready-\(UUID().uuidString)")
        let backoffReleaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-backoff-release-\(UUID().uuidString)")
        let attachDoneURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-done-\(UUID().uuidString)")
        let transcriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-queued-input-transcript-\(UUID().uuidString)")
        let fakeCLIURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-input-flush-\(UUID().uuidString)")
        try Data().write(to: transcriptURL)
        try """
        #!/bin/sh
        if [ "${1:-}" = "__ssh-pty-flush-input" ]; then
          exec /usr/bin/python3 -c 'import sys, termios; termios.tcflush(sys.stdin.fileno(), termios.TCIFLUSH)'
        fi
        exit 0
        """.write(to: fakeCLIURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: fakeCLIURL.path
        )
        let transcriptHandle = try FileHandle(forWritingTo: transcriptURL)
        defer {
            try? transcriptHandle.close()
            try? FileManager.default.removeItem(at: logURL)
            try? FileManager.default.removeItem(at: backoffMarkerURL)
            try? FileManager.default.removeItem(at: backoffReleaseURL)
            try? FileManager.default.removeItem(at: attachDoneURL)
            try? FileManager.default.removeItem(at: transcriptURL)
            try? FileManager.default.removeItem(at: fakeCLIURL)
        }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: false
        )
        let script = ([
            "hmux_ssh_attach_cli=",
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "hmux_ssh_attach_cli=\"$HMUX_TEST_FAKE_CLI\"",
            "sleep() { printf 'ready\\n' > \"$HMUX_TEST_BACKOFF_MARKER\"; while [ ! -f \"$HMUX_TEST_BACKOFF_RELEASE\" ]; do /bin/sleep 0.01; done; }",
            "hmux_test_attach() {",
            "  count=$(grep -c '^attach$' \"$HMUX_TEST_LOG\" 2>/dev/null) || count=0",
            "  printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"",
            "  if [ \"$count\" -eq 0 ]; then return 255; fi",
            "  HMUX_TEST_LOG=\"$HMUX_TEST_LOG\" HMUX_TEST_ATTACH_DONE=\"$HMUX_TEST_ATTACH_DONE\" /usr/bin/python3 -c 'import os, select, sys; os.set_blocking(0, False); ready, _, _ = select.select([0], [], [], 0); data = os.read(0, 8192) if ready else b\"\"; open(os.environ[\"HMUX_TEST_ATTACH_DONE\"], \"w\").write(\"done\\n\"); open(os.environ[\"HMUX_TEST_LOG\"], \"a\").write(\"input:\" + data.decode(errors=\"replace\") + \"\\n\" if data else \"\")'",
            "  return 0",
            "}",
        ] + retryLines).joined(separator: "\n")

        let process = Process()
        let standardInput = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "/dev/null", "/bin/sh", "-c", script]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "HMUX_TEST_LOG": logURL.path,
            "HMUX_TEST_BACKOFF_MARKER": backoffMarkerURL.path,
            "HMUX_TEST_BACKOFF_RELEASE": backoffReleaseURL.path,
            "HMUX_TEST_ATTACH_DONE": attachDoneURL.path,
            "HMUX_TEST_FAKE_CLI": fakeCLIURL.path,
            "HMUX_SSH_RECONNECT_DELAY_SECONDS": "1",
            "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "1",
        ]) { _, override in override }
        process.standardInput = standardInput
        process.standardOutput = transcriptHandle
        process.standardError = FileHandle.nullDevice

        try process.run()
        let enteredBackoff = waitForFile(
            at: backoffMarkerURL,
            containing: "ready",
            while: process,
            timeout: 3
        )
        #expect(enteredBackoff)
        if enteredBackoff {
            try standardInput.fileHandleForWriting.write(contentsOf: Data("queued-input\n".utf8))
            try Data().write(to: backoffReleaseURL)
        }
        let secondAttachFinished = waitForFile(
            at: attachDoneURL,
            containing: "done",
            while: process,
            timeout: 3
        )
        #expect(secondAttachFinished)
        try? standardInput.fileHandleForWriting.close()
        if !secondAttachFinished, process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()

        let logContents = (try? String(contentsOf: logURL, encoding: .utf8)) ?? "<missing>"
        #expect(process.terminationStatus == 0)
        #expect(logContents == "attach\nattach\n")
    }

    @Test func reconnectStatusUpdatesOneLineAndShowsBackoff() throws {
        let attemptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-status-attempt-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: attemptURL) }
        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: false
        )
        let script = ([
            "hmux_ssh_attach_cli=",
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "sleep() { :; }",
            "hmux_test_attach() {",
            "  if [ ! -f \"$HMUX_TEST_STATUS_ATTEMPT\" ]; then : > \"$HMUX_TEST_STATUS_ATTEMPT\"; return 255; fi",
            "  return 253",
            "}",
        ] + retryLines).joined(separator: "\n")

        let process = Process()
        let transcriptPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "/dev/null", "/bin/sh", "-c", script]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "HMUX_TEST_STATUS_ATTEMPT": attemptURL.path,
            "HMUX_SSH_RECONNECT_DELAY_SECONDS": "8",
            "HMUX_SSH_RECONNECT_MAX_DELAY_SECONDS": "8",
        ]) { _, override in override }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = transcriptPipe
        process.standardError = transcriptPipe

        try process.run()
        let transcriptData = transcriptPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let transcript = String(data: transcriptData, encoding: .utf8) ?? ""

        #expect(process.terminationStatus == 253, Comment(rawValue: transcript))
        #expect(transcript.contains("SSH disconnected"), Comment(rawValue: transcript))
        #expect(transcript.contains("retry 1 in 8s"), Comment(rawValue: transcript))
        #expect(transcript.contains("input discarded"), Comment(rawValue: transcript))
        #expect(transcript.contains("\r\u{1B}[2K"), Comment(rawValue: transcript))
        #expect(!transcript.contains("remote PTY bridge closed; reattaching"), Comment(rawValue: transcript))
    }

    @Test(arguments: ["bad", "-5", "0"])
    func unusableReconnectLimitsRemainFinite(_ configuredLimit: String) throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-limit-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: false
        )
        let script = ([
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "sleep() { :; }",
            "hmux_test_attach() { printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"; return 255; }",
        ] + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "HMUX_TEST_LOG": logURL.path,
                "HMUX_SSH_RECONNECT_LIMIT": configuredLimit,
            ]
        )
        let attempts = try String(contentsOf: logURL, encoding: .utf8)
            .split(separator: "\n")
            .count

        #expect(result.status == 255)
        // One initial attach plus the 20 fallback reconnects is the contract
        // for text the supervisor cannot use as an attempt count.
        #expect(attempts == 21)
        #expect(
            result.stderr.contains("HMUX_SSH_RECONNECT_LIMIT=\(configuredLimit)"),
            Comment(rawValue: result.stderr)
        )
    }

    @Test func wellFormedReconnectLimitAboveTwentyIsHonored() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-limit-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: false
        )
        let script = ([
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "sleep() { :; }",
            "hmux_test_attach() { printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"; return 255; }",
        ] + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "HMUX_TEST_LOG": logURL.path,
                "HMUX_SSH_RECONNECT_LIMIT": "25",
            ]
        )
        let attempts = try String(contentsOf: logURL, encoding: .utf8)
            .split(separator: "\n")
            .count

        #expect(result.status == 255)
        // 25 used to be rewritten to 20 without a word. The supervisor now
        // spends the budget it was given, and stays silent about it.
        #expect(attempts == 26)
        #expect(!result.stderr.contains("HMUX_SSH_RECONNECT_LIMIT="), Comment(rawValue: result.stderr))
    }

    @Test
    func retryableAttachIsCappedAtTwentyReconnects() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-ssh-attach-budget-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: logURL) }

        let retryLines = SSHPTYAttachRetryScriptBuilder().lines(
            command: "hmux_test_attach",
            reauthenticates: false
        )
        let script = ([
            "hmux_ssh_attach_signal_exit() { exit \"$1\"; }",
            "sleep() { :; }",
            "hmux_test_attach() { printf '%s\\n' attach >> \"$HMUX_TEST_LOG\"; return 255; }",
        ] + retryLines).joined(separator: "\n")

        let result = try run(
            script,
            environment: [
                "HMUX_TEST_LOG": logURL.path,
                "HMUX_SSH_RECONNECT_LIMIT": "20",
            ]
        )

        #expect(result.status == 255)
        let attempts = try String(contentsOf: logURL, encoding: .utf8)
            .split(separator: "\n")
        #expect(attempts == Array(repeating: Substring("attach"), count: 21))
    }

    private func waitForFile(
        at url: URL,
        containing expectedContents: String,
        while process: Process,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if contents.contains(expectedContents) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        let finalContents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return finalContents.contains(expectedContents)
    }

    private func run(
        _ script: String,
        environment overrides: [String: String]
    ) throws -> (status: Int32, stderr: String) {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.environment = ProcessInfo.processInfo.environment.merging(overrides) { _, override in override }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        try process.run()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}
