internal import HmuxMobileSSH
internal import HmuxMobileSupport
import Foundation

/// Whether one workspace kind can be created on a host, and why not.
public struct MobileSSHKindAvailability: Equatable, Sendable, Identifiable {
    public var kind: MobileSSHWorkspaceKind
    /// `nil` when the kind can be created.
    public var unavailableReason: String?
    /// hmux-tui only: the first workspace uploads hmux-tui first (PRD D10).
    public var needsInstall: Bool

    public var id: MobileSSHWorkspaceKind { kind }
    public var isAvailable: Bool { unavailableReason == nil }

    public init(kind: MobileSSHWorkspaceKind, unavailableReason: String? = nil, needsInstall: Bool = false) {
        self.kind = kind
        self.unavailableReason = unavailableReason
        self.needsInstall = needsInstall
    }

    /// Before the host is probed every kind is offered; creating one
    /// connects first and reports a real failure on the host.
    public static let unprobed: [MobileSSHKindAvailability] = MobileSSHWorkspaceKind.allCases.map {
        MobileSSHKindAvailability(kind: $0)
    }
}

/// Every workspace kind one SSH connection serves at once (PRD D31): the
/// phone's plain shells always, tmux sessions when tmux is installed, and
/// hmux-tui workspaces from every hmux-tui session on the server when
/// hmux-tui is installed (the phone's own session is created on the first
/// hmux-tui workspace, uploading hmux-tui if needed).
///
/// Every id leaving the registry is a kind-encoded ``MobileSSHLocalID``
/// raw value; every id entering it is parsed back and dispatched to its
/// kind's provider with the provider's own id.
@MainActor
final class MobileSSHHostProviders {
    private let connection: SSHConnection?
    private let idleCloseSeconds: Int?
    /// tmux (a ``MobileSSHTmuxProvider`` in the app); `nil` when tmux is
    /// not installed.
    private(set) var tmux: (any MobileSSHWorkspaceProvider)?
    private let plain: any MobileSSHWorkspaceProvider
    /// The installed hmux-tui binary, if any.
    private(set) var hmuxTUIBinary: String?
    /// `uname` of the server, for the installer and the unsupported reason.
    private let hmuxTUIProbe: HmuxTUIProbe?
    /// One provider per hmux-tui session, created on first use.
    private var hmuxTUI: [String: MobileSSHHmuxTUIProvider] = [:]
    var onTopologyChange: (@MainActor () -> Void)? {
        didSet {
            (tmux as? any MobileSSHTopologyReporting)?.onTopologyChange = onTopologyChange
            for provider in hmuxTUI.values { provider.onTopologyChange = onTopologyChange }
        }
    }

    private init(
        connection: SSHConnection?,
        idleCloseSeconds: Int?,
        tmux: (any MobileSSHWorkspaceProvider)?,
        plain: any MobileSSHWorkspaceProvider,
        hmuxTUIBinary: String?,
        hmuxTUIProbe: HmuxTUIProbe?
    ) {
        self.connection = connection
        self.idleCloseSeconds = idleCloseSeconds
        self.tmux = tmux
        self.plain = plain
        self.hmuxTUIBinary = hmuxTUIBinary
        self.hmuxTUIProbe = hmuxTUIProbe
    }

    /// Probes the host once per connection: tmux, an installed hmux-tui, and
    /// the platform (for installing one). Probes never fail the connection.
    static func make(connection: SSHConnection, host: SSHHostRecord) async -> MobileSSHHostProviders {
        async let tmuxPath = MobileSSHTmuxProvider.probe(on: connection)
        async let binary = HmuxTUIRemote.locateBinary(on: connection)
        async let probe = try? HmuxTUIRemote().probe(on: connection)
        let tmux = await tmuxPath.map { MobileSSHTmuxProvider(connection: connection, tmuxPath: $0) }
        return await MobileSSHHostProviders(
            connection: connection,
            idleCloseSeconds: host.idleClose.seconds,
            tmux: tmux,
            plain: MobileSSHPlainProvider(connection: connection),
            hmuxTUIBinary: binary,
            hmuxTUIProbe: probe
        )
    }

    /// Test seam: a host whose tmux is `tmux` and that has no hmux-tui.
    static func testing(tmux: any MobileSSHWorkspaceProvider, plain: (any MobileSSHWorkspaceProvider)? = nil) -> MobileSSHHostProviders {
        MobileSSHHostProviders(
            connection: nil,
            idleCloseSeconds: nil,
            tmux: tmux,
            plain: plain ?? MobileSSHPlainProvider(connection: nil),
            hmuxTUIBinary: nil,
            hmuxTUIProbe: nil
        )
    }

    // MARK: Availability

    var availability: [MobileSSHKindAvailability] {
        MobileSSHWorkspaceKind.allCases.map { kind in
            switch kind {
            case .hmuxTUI:
                if hmuxTUIBinary != nil { return MobileSSHKindAvailability(kind: kind) }
                guard let probe = hmuxTUIProbe, probe.npmPlatformPackage != nil else {
                    let os = hmuxTUIProbe?.os ?? "?"
                    let arch = hmuxTUIProbe?.arch ?? "?"
                    return MobileSSHKindAvailability(kind: kind, unavailableReason: L10nSSH().hmuxTUIUnsupported(os: os, arch: arch))
                }
                return MobileSSHKindAvailability(kind: kind, needsInstall: true)
            case .tmux:
                return MobileSSHKindAvailability(kind: kind, unavailableReason: tmux == nil ? L10nSSH().tmuxMissing : nil)
            case .shell:
                return MobileSSHKindAvailability(kind: kind)
            }
        }
    }

    // MARK: Listing

    /// Every workspace of every kind, hmux-tui first, then tmux, then shells.
    /// A hmux-tui session whose owner does not answer is skipped; transport
    /// failures (the connection is gone) propagate.
    func listWorkspaces() async throws -> [MobileSSHWorkspace] {
        var result: [MobileSSHWorkspace] = []
        for provider in try await liveHmuxTUIProviders() {
            guard let workspaces = try? await provider.listWorkspaces() else {
                await dropHmuxTUI(session: provider.session)
                continue
            }
            result += workspaces.map { Self.rekey($0, kind: .hmuxTUI, session: provider.session) }
        }
        if let tmux {
            result += try await tmux.listWorkspaces().map { Self.rekey($0, kind: .tmux, session: nil) }
        }
        result += try await plain.listWorkspaces().map { Self.rekey($0, kind: .shell, session: nil) }
        return result
    }

    /// Providers for every session with a socket on the server, connecting
    /// new ones. Nothing is started and nothing is installed to list.
    private func liveHmuxTUIProviders() async throws -> [MobileSSHHmuxTUIProvider] {
        guard let connection, let binary = hmuxTUIBinary else { return [] }
        let sockets = try await HmuxTUIRemote(binaryPath: binary).listSessionSockets(on: connection)
        var providers: [MobileSSHHmuxTUIProvider] = []
        for socket in sockets {
            if let provider = cachedHmuxTUIProvider(for: socket) {
                providers.append(provider)
                continue
            }
            let provider = hmuxTUIProvider(session: socket.name ?? socket.digest, socket: socket, connection: connection, binary: binary)
            do {
                try await provider.connect()
                // A hashed socket learns its name from the owner; a name
                // of another digest means the owner is not this socket's.
                guard socket.serves(session: provider.session) else {
                    await provider.close()
                    continue
                }
                if let existing = hmuxTUI[provider.session] {
                    await provider.close()
                    providers.append(existing)
                } else {
                    hmuxTUI[provider.session] = provider
                    providers.append(provider)
                }
            } catch {
                await provider.close()
            }
        }
        return providers
    }

    /// The cached provider of the session behind `socket`: by name, or for a
    /// hashed socket by the digest of each cached session's name.
    private func cachedHmuxTUIProvider(for socket: HmuxTUISessionSocket) -> MobileSSHHmuxTUIProvider? {
        if let name = socket.name { return hmuxTUI[name] }
        return hmuxTUI.values.first { socket.serves(session: $0.session) }
    }

    private func hmuxTUIProvider(
        session: String,
        socket: HmuxTUISessionSocket?,
        connection: SSHConnection,
        binary: String
    ) -> MobileSSHHmuxTUIProvider {
        // The phone's own session may be (re)started; any other session
        // belongs to whoever started it and is only ever reached.
        let route: MobileSSHHmuxTUIProvider.Route = if session == MobileSSHHmuxTUIProvider.sessionName || socket == nil {
            .ensure
        } else {
            .socket(socket!)
        }
        let provider = MobileSSHHmuxTUIProvider(
            connection: connection,
            remote: HmuxTUIRemote(binaryPath: binary),
            session: session,
            route: route,
            idleCloseSeconds: idleCloseSeconds
        )
        provider.onTopologyChange = onTopologyChange
        return provider
    }

    private func dropHmuxTUI(session: String) async {
        await hmuxTUI.removeValue(forKey: session)?.close()
    }

    /// Re-keys a provider's workspace (and its terminals and browsers) to
    /// kind-encoded local ids.
    static func rekey(_ workspace: MobileSSHWorkspace, kind: MobileSSHWorkspaceKind, session: String?) -> MobileSSHWorkspace {
        func local(_ id: String) -> String {
            switch kind {
            case .hmuxTUI: MobileSSHLocalID.hmuxTUI(session: session ?? MobileSSHHmuxTUIProvider.sessionName, id: id).rawValue
            case .tmux: MobileSSHLocalID.tmux(id).rawValue
            case .shell: MobileSSHLocalID.shell(id).rawValue
            }
        }
        var workspace = workspace
        workspace.kind = kind
        workspace.hmuxTUISession = kind == .hmuxTUI ? session : nil
        workspace.id = local(workspace.id)
        workspace.terminals = workspace.terminals.map { terminal in
            var terminal = terminal
            terminal.id = local(terminal.id)
            return terminal
        }
        workspace.browsers = workspace.browsers.map { browser in
            var browser = browser
            browser.id = local(browser.id)
            return browser
        }
        return workspace
    }

    // MARK: Dispatch

    /// The provider serving a local id, connecting a hmux-tui session on
    /// first use.
    func provider(for local: MobileSSHLocalID) async throws -> any MobileSSHWorkspaceProvider {
        switch local {
        case .tmux:
            guard let tmux else { throw MobileSSHRuntimeError.tmuxMissing }
            return tmux
        case .shell:
            return plain
        case .hmuxTUI(let session, _):
            return try await hmuxTUIProvider(session: session)
        }
    }

    /// The provider of a hmux-tui session: cached, the phone's own session
    /// (started if needed), or a live socket found on the server.
    func hmuxTUIProvider(session: String) async throws -> MobileSSHHmuxTUIProvider {
        if let provider = hmuxTUI[session] { return provider }
        guard let connection, let binary = hmuxTUIBinary else { throw MobileSSHRuntimeError.hmuxTUIMissing }
        var socket: HmuxTUISessionSocket?
        if session != MobileSSHHmuxTUIProvider.sessionName {
            socket = try await HmuxTUIRemote(binaryPath: binary).listSessionSockets(on: connection).first { $0.serves(session: session) }
            guard socket != nil else { throw MobileSSHRuntimeError.hmuxTUISessionGone }
        }
        let provider = hmuxTUIProvider(session: session, socket: socket, connection: connection, binary: binary)
        hmuxTUI[session] = provider
        return provider
    }

    /// Creates a top-level primitive of `kind` and returns it re-keyed.
    /// The first hmux-tui workspace on a host without hmux-tui installs it
    /// (PRD D10), reporting through `installing`.
    func createWorkspace(
        kind: MobileSSHWorkspaceKind,
        installing: @escaping @MainActor (Bool) -> Void
    ) async throws -> MobileSSHWorkspace {
        switch kind {
        case .shell:
            return Self.rekey(try await plain.createWorkspace(), kind: .shell, session: nil)
        case .tmux:
            guard let tmux else { throw MobileSSHRuntimeError.tmuxMissing }
            return Self.rekey(try await tmux.createWorkspace(), kind: .tmux, session: nil)
        case .hmuxTUI:
            try await installHmuxTUIIfNeeded(installing: installing)
            let provider = try await hmuxTUIProvider(session: MobileSSHHmuxTUIProvider.sessionName)
            return Self.rekey(try await provider.createWorkspace(), kind: .hmuxTUI, session: provider.session)
        }
    }

    private func installHmuxTUIIfNeeded(installing: @escaping @MainActor (Bool) -> Void) async throws {
        guard hmuxTUIBinary == nil else { return }
        guard let connection else { throw MobileSSHRuntimeError.hmuxTUIMissing }
        var probe = hmuxTUIProbe
        if probe == nil { probe = try? await HmuxTUIRemote().probe(on: connection) }
        guard let probe else { throw MobileSSHRuntimeError.hmuxTUIMissing }
        installing(true)
        defer { installing(false) }
        try await MobileSSHHmuxTUIInstaller().install(probe: probe, on: connection) { _ in }
        hmuxTUIBinary = HmuxTUIRemote.defaultBinaryPath
    }

    /// "New Window" (tmux) / "New Screen" (hmux-tui) in a workspace.
    func createTerminal(inWorkspace local: MobileSSHLocalID) async throws -> MobileSSHLocalID? {
        guard let creator = try await provider(for: local) as? any MobileSSHTerminalCreating else { return nil }
        let terminal = try await creator.createTerminal(inWorkspace: local.providerID)
        return local.sibling(terminal.id)
    }

    /// A section-level action: "Split Right" / "Split Down" on a tmux
    /// window; "New Tab" or a split on a hmux-tui screen (acting on `pane`,
    /// its active pane).
    func createTab(
        inWorkspace local: MobileSSHLocalID,
        section: String,
        pane: Int?,
        action: MobileSSHSectionAction
    ) async throws -> MobileSSHLocalID? {
        switch local {
        case .tmux(let session):
            guard let direction = action.splitDirection else { return nil }
            guard let tmux = tmux as? MobileSSHTmuxProvider else { throw MobileSSHRuntimeError.tmuxMissing }
            return local.sibling(try await tmux.splitWindow(inWorkspace: session, window: section, direction: direction).id)
        case .hmuxTUI(let session, let key):
            guard let pane else { return nil }
            let provider = try await hmuxTUIProvider(session: session)
            let terminal = if let direction = action.splitDirection {
                try await provider.splitPane(inWorkspace: key, pane: pane, direction: direction)
            } else {
                try await provider.createTab(inWorkspace: key, pane: pane)
            }
            return local.sibling(terminal.id)
        case .shell:
            return nil
        }
    }
}

extension MobileSSHLocalID {
    /// Another id of the same kind (and hmux-tui session).
    func sibling(_ providerID: String) -> MobileSSHLocalID {
        switch self {
        case .hmuxTUI(let session, _): .hmuxTUI(session: session, id: providerID)
        case .tmux: .tmux(providerID)
        case .shell: .shell(providerID)
        }
    }
}
