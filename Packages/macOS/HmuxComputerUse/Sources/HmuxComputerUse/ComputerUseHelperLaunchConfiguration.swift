import AppKit
import Foundation
import HmuxFoundation

/// LaunchServices arguments and environment for the hmux-cua helper daemon.
struct ComputerUseHelperLaunchConfiguration: Equatable, Sendable {
    let arguments: [String]
    let environment: [String: String]

    @MainActor
    func workspaceConfiguration(
        helperURL: URL,
        fileManager: FileManager = .default
    ) -> NSWorkspace.OpenConfiguration? {
        let executable = helperURL.appendingPathComponent("Contents/MacOS/hmux-cua")
        guard
            let attributes = try? fileManager.attributesOfItem(atPath: executable.path),
            attributes[.type] as? FileAttributeType == .typeRegular,
            fileManager.isExecutableFile(atPath: executable.path)
        else { return nil }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        // Health checks retry in the background. Launch failures must reach the
        // completion handler without waiting on another Finder error dialog.
        configuration.promptsUserIfNeeded = false
        configuration.arguments = arguments
        configuration.environment = environment
        return configuration
    }

    init?(
        paths: ComputerUseRuntimePaths,
        profile: ComputerUseDaemonProfile = .native,
        rootProcessIdentity: AgentPIDProcessIdentity? = AgentPIDProcessIdentity(
            pid: ProcessInfo.processInfo.processIdentifier
        )
    ) {
        guard let rootProcessIdentity else { return nil }
        var arguments = [
            "serve",
            "--socket",
            profile == .native
                ? paths.daemonSocketURL.path
                : paths.codexDaemonSocketURL.path,
        ]
        if profile == .codexCompatibility {
            arguments.append("--codex-computer-use-compat")
        }
        arguments.append(contentsOf: [
            "--no-permissions-gate",
            "--cursor-shape",
            "hmux",
            // The proxy's control connection owns cursor teardown and sends
            // session_end on EOF/crash. A wall-clock idle timer measures gaps
            // between model calls, not task completion, and hides the cursor
            // while a still-active agent is inspecting the returned state.
            "--idle-hide-ms",
            "0",
            // Glide-speed multiplier over the driver's stock 900 pts/s peak.
            // Stock pacing reads as sluggish between agent actions; press and
            // dwell visuals keep their durations so clicks stay legible.
            "--cursor-speed",
            "1.75",
        ])
        self.arguments = arguments
        environment = [
            "HMUX_CUA_EXTERNAL_PERMISSION_FLOW": "1",
            "HMUX_CUA_PERMISSIONS_GATE": "0",
            // LaunchServices already establishes the helper as a separate GUI
            // responsibility. The hmux-cua helper is already the canonical
            // executable inside its branded bundle, so it must not re-exec or
            // launch a second `serve` process.
            "HMUX_CUA_RESPONSIBILITY_DISCLAIMED": "1",
            "HMUX_CUA_TELEMETRY_ENABLED": "false",
            "HMUX_CUA_UPDATE_CHECK": "false",
            "HMUX_CUA_CURSOR_GRADIENT": "#12c7f5,#2d8cff,#6c5cff",
            "HMUX_CUA_CURSOR_BLOOM": "#2d8cff",
            "HMUX_CUA_CURSOR_LABEL": "hmux",
            "HMUX_CUA_STATE_DIR": paths.stateDirectoryURL.path,
            ComputerUseRuntimePaths.authenticationTokenEnvironmentKey: paths.authenticationToken,
            ComputerUseRuntimePaths.hostAuthenticationTokenEnvironmentKey:
                paths.hostAuthenticationToken,
            "HMUX_CUA_SOCKET_AUTHORIZED_ROOT_PID":
                String(rootProcessIdentity.pid),
            "HMUX_CUA_SOCKET_AUTHORIZED_ROOT_START_SECONDS":
                String(rootProcessIdentity.startSeconds),
            "HMUX_CUA_SOCKET_AUTHORIZED_ROOT_START_MICROSECONDS":
                String(rootProcessIdentity.startMicroseconds),
        ]
    }
}
