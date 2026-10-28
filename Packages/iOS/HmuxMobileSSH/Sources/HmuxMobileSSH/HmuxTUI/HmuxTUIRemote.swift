import Foundation

/// Entry point for using hmux-tui on an SSH host as a persistence layer.
///
/// A headless hmux-tui owner holds the terminals; the phone connects through
/// `hmux-tui relay`, which copies the session's JSON-lines control socket over
/// an SSH exec channel. Terminals survive the phone disconnecting, the relay
/// exiting, and the owner restarting (terminal-host processes persist).
public actor HmuxTUIRemote {
    /// The install location `hmux-tui remote ssh` probes (docs/remote.md).
    public static let defaultBinaryPath = "~/.local/bin/hmux-tui"

    /// Remote path of the hmux-tui binary. A leading `~/` expands to `$HOME`.
    public nonisolated let binaryPath: String

    public init(binaryPath: String = HmuxTUIRemote.defaultBinaryPath) {
        self.binaryPath = binaryPath
    }

    /// Reports the host's OS/arch and the installed binary, if any.
    public func probe(on connection: SSHConnection) async throws -> HmuxTUIProbe {
        let script = """
        uname -s; uname -m
        B=\(binaryPath.remoteShellPath)
        printf '%s\\n' "$B"
        if [ -x "$B" ]; then "$B" remote-probe --json 2>/dev/null || "$B" --version 2>/dev/null || echo; else echo missing; fi
        """
        let result = try await connection.exec(script.bourneShellCommand)
        let lines = result.stdoutString.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 4 else {
            throw HmuxTUIError.malformedResponse("probe: \(result.stdoutString)\(result.stderrString)")
        }
        let raw = lines[3...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return HmuxTUIProbe(
            os: lines[0],
            arch: lines[1],
            binaryPath: lines[2],
            installed: raw == "missing" ? nil : Self.parseInstalled(raw)
        )
    }

    /// Starts the session's headless owner if needed (`server ensure`), then
    /// opens a relay channel and completes the `identify` handshake.
    ///
    /// - Parameters:
    ///   - session: session name; one owner and socket per name. Use a
    ///     product-scoped name (e.g. `hmux-ios`) rather than `main`.
    ///   - clientName: label shown by `list-clients`.
    public func connect(
        on connection: SSHConnection,
        session: String,
        clientName: String = "hmux-ios",
        handshakeTimeout: Duration = .seconds(30)
    ) async throws -> HmuxTUIControl {
        try Self.validate(session: session)
        let script = """
        B=\(binaryPath.remoteShellPath); S=\(session.posixShellSingleQuoted)
        [ -x "$B" ] || { echo "hmux-tui not found at $B" >&2; exit 127; }
        "$B" server ensure --session "$S" --json >&2 || exit $?
        exec "$B" relay --session "$S"
        """
        let channel = try await connection.openSession(start: .exec(script.bourneShellCommand))
        return try await HmuxTUIControl.open(
            channel: channel,
            session: session,
            clientName: clientName,
            handshakeTimeout: handshakeTimeout
        )
    }

    /// Stops the session's owner (`server stop`). Terminal-host processes and
    /// durable topology survive; the next `connect` restores them.
    @discardableResult
    public func stopServer(on connection: SSHConnection, session: String) async throws -> SSHExecResult {
        try Self.validate(session: session)
        let script = "\(binaryPath.remoteShellPath) server stop --session \(session.posixShellSingleQuoted) --json"
        return try await connection.exec(script.bourneShellCommand)
    }

    /// Mirrors the server's session-name rule (single path component, no
    /// whitespace or control characters, at most 64 bytes).
    static func validate(session: String) throws {
        let invalid = session.isEmpty
            || session.utf8.count > 64
            || session == "." || session == ".."
            || session.contains("/") || session.contains("\\")
            || session.unicodeScalars.contains { $0.properties.isWhitespace || $0.properties.generalCategory == .control }
        if invalid { throw HmuxTUIError.invalidSessionName(session) }
    }

    static func parseInstalled(_ raw: String) -> HmuxTUIInstalledBinary {
        struct Probe: Decodable {
            var version: String?
            var distribution_version: String?
            var build_identity: String?
            var remote_protocol: Int?
        }
        if raw.hasPrefix("{"), let probe = try? JSONDecoder().decode(Probe.self, from: Data(raw.utf8)) {
            return HmuxTUIInstalledBinary(
                version: probe.version,
                distributionVersion: probe.distribution_version,
                buildIdentity: probe.build_identity,
                remoteProtocol: probe.remote_protocol,
                rawProbe: raw
            )
        }
        // `hmux 0.1.0 (<commit>; ghostty <commit>)`
        let words = raw.split(separator: " ")
        let version = words.count >= 2 ? String(words[1]) : nil
        return HmuxTUIInstalledBinary(version: version, distributionVersion: nil, buildIdentity: nil, remoteProtocol: nil, rawProbe: raw)
    }
}
