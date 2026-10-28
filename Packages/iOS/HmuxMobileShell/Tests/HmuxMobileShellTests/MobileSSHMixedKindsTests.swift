@testable import HmuxMobileShell
import HmuxMobileShellModel
import HmuxMobileSSH
import Foundation
import Testing

/// Round 3 (PRD D31-D33): one SSH host serves hmux-tui workspaces, tmux
/// sessions, and shells at once. Ids encode the kind, rows name it, and the
/// tab switcher groups terminals by tmux window or hmux-tui screen.
@MainActor
@Suite struct MobileSSHMixedKindsTests {
    // MARK: Ids

    @Test func localIDsEncodeKindAndRoundTrip() throws {
        let ids: [MobileSSHLocalID] = [
            .hmuxTUI(session: "hmux-ios", id: "5f0e-key"),
            .hmuxTUI(session: "main", id: "term_abc"),
            .tmux("work"),
            .tmux("a/b/%12"),
            .shell("3"),
        ]
        for id in ids {
            #expect(MobileSSHLocalID(rawValue: id.rawValue) == id)
        }
        #expect(MobileSSHLocalID.hmuxTUI(session: "main", id: "term_abc").rawValue == "tui:main/term_abc")
        #expect(MobileSSHLocalID.tmux("a/b/%12").providerID == "a/b/%12")
        #expect(MobileSSHLocalID(rawValue: "work") == nil)
        #expect(MobileSSHLocalID(rawValue: "tui:no-slash") == nil)
        #expect(MobileSSHLocalID(rawValue: "shell:") == nil)

        // Through a scoped id, including a tmux session name with `~`.
        let host = UUID()
        let scoped = MobileSSHIdentifier(host: host, local: MobileSSHLocalID.tmux("x~y/%4").rawValue).rawValue
        #expect(MobileSSHIdentifier(scoped).hostID == host)
        #expect(MobileSSHLocalID(scopedID: scoped) == .tmux("x~y/%4"))
        #expect(MobileSSHLocalID.tmux("a").sibling("a/%9") == .tmux("a/%9"))
        #expect(MobileSSHLocalID.hmuxTUI(session: "s", id: "k").sibling("term_1") == .hmuxTUI(session: "s", id: "term_1"))
    }

    /// The same provider id in two kinds never collides once re-keyed.
    @Test func rekeyingSeparatesKindsAndHmuxTUISessions() {
        let workspace = MobileSSHWorkspace(id: "1", name: "one", terminals: [MobileSSHTerminal(id: "1", name: "one")])
        let shell = MobileSSHHostProviders.rekey(workspace, kind: .shell, session: nil)
        let tmux = MobileSSHHostProviders.rekey(workspace, kind: .tmux, session: nil)
        let own = MobileSSHHostProviders.rekey(workspace, kind: .hmuxTUI, session: "hmux-ios")
        let laptop = MobileSSHHostProviders.rekey(workspace, kind: .hmuxTUI, session: "main")
        #expect(Set([shell.id, tmux.id, own.id, laptop.id]).count == 4)
        #expect(shell.terminals[0].id == "shell:1")
        #expect(laptop.terminals[0].id == "tui:main/1")
        #expect(laptop.kind == .hmuxTUI)
        #expect(laptop.hmuxTUISession == "main")
        #expect(tmux.hmuxTUISession == nil)
    }

    // MARK: Row subtitle

    @Test func rowSubtitleNamesTheKind() {
        #expect(L10nSSH().kindLabel(.tmux) == "tmux session")
        #expect(L10nSSH().kindLabel(.shell) == "Shell")
        #expect(L10nSSH().kindLabel(.hmuxTUI, hmuxTUISession: MobileSSHHmuxTUIProvider.sessionName) == "hmux-tui")
        // Another hmux-tui session's workspace names that session.
        #expect(L10nSSH().kindLabel(.hmuxTUI, hmuxTUISession: "main") == "hmux-tui · main")
    }

    // MARK: Grouped tab switcher

    /// A hmux-tui workspace: screen 1 has two panes (the second holding two
    /// tabs), screen 2 is unnamed with one pane. Sections follow screens,
    /// rows follow layout order, a pane change starts a group, and pane
    /// labels appear only where a screen has several panes.
    @Test func hmuxTUIScreensBecomeSectionsWithPaneGroups() throws {
        let tui = HmuxTUIWorkspace(
            id: 4,
            key: "k1",
            name: "api",
            terminals: [
                HmuxTUITerminal(surface: 1, pane: 10, screen: 100, resourceID: "term_a", title: "zsh"),
                HmuxTUITerminal(surface: 2, pane: 11, screen: 100, resourceID: "term_b", name: "server"),
                HmuxTUITerminal(surface: 3, pane: 11, screen: 100, resourceID: "term_c", title: "logs"),
                HmuxTUITerminal(surface: 4, pane: 20, screen: 200, resourceID: "term_d", title: "vim"),
                HmuxTUITerminal(surface: 5, pane: 20, screen: 200, resourceID: "term_dead", dead: true),
            ],
            screens: [
                HmuxTUIScreen(id: 100, name: "dev", activePane: 11, panes: [HmuxTUIPane(id: 10), HmuxTUIPane(id: 11)]),
                HmuxTUIScreen(id: 200, name: nil, activePane: nil, panes: [HmuxTUIPane(id: 20)]),
            ]
        )
        let host = UUID()
        let workspace = MobileSSHHostProviders.rekey(MobileSSHHmuxTUIProvider.workspace(tui), kind: .hmuxTUI, session: "main")
        #expect(workspace.id == "tui:main/k1")
        #expect(workspace.terminals.map(\.id) == ["tui:main/term_a", "tui:main/term_b", "tui:main/term_c", "tui:main/term_d"])
        #expect(workspace.sections.map(\.targetPane) == [11, 20])

        let layout = MobileSSHComputers.tabLayout(workspace, hostID: host)
        #expect(layout.kind == .hmuxTUI)
        #expect(layout.sections.map(\.title) == ["dev", "Screen 2"])
        #expect(layout.sections.allSatisfy { $0.canAddTab })
        let dev = try #require(layout.sections.first)
        #expect(dev.rows.map(\.title) == ["zsh", "server", "logs"])
        #expect(dev.rows.map(\.paneLabel) == ["Pane 1", "Pane 2", "Pane 2"])
        #expect(dev.rows.map(\.startsPane) == [false, true, false])
        #expect(dev.rows.first?.id == MobileSSHIdentifier(host: host, local: "tui:main/term_a").rawValue)
        let second = try #require(layout.sections.last)
        #expect(second.rows.map(\.title) == ["vim"])
        #expect(second.rows.first?.paneLabel == nil)
    }

    /// tmux: one section per window, a pane row per pane; split windows
    /// label rows by pane, single-pane windows by window name.
    @Test func tmuxWindowsBecomeSections() throws {
        let rows = MobileSSHTmuxProvider.parsePaneRows([
            "work:0:2:%1:0:zsh",
            "work:0:2:%2:1:zsh",
            "work:1:1:%5:0:logs: tail",
        ].joined(separator: "\n"))
        let workspace = try #require(MobileSSHTmuxProvider.workspaces(from: rows).first)
        let rekeyed = MobileSSHHostProviders.rekey(workspace, kind: .tmux, session: nil)
        let layout = MobileSSHComputers.tabLayout(rekeyed, hostID: UUID())
        #expect(layout.kind == .tmux)
        #expect(layout.sections.map(\.id) == ["0", "1"])
        #expect(layout.sections.map(\.title) == ["0: zsh", "1: logs: tail"])
        #expect(layout.sections[0].rows.map(\.title) == ["Pane 1", "Pane 2"])
        #expect(layout.sections[0].rows.map(\.startsPane) == [false, true])
        #expect(layout.sections[1].rows.map(\.title) == ["logs: tail"])
        #expect(layout.sections.allSatisfy { $0.canAddTab })
        // Terminal titles keep the full window/pane name for the title bar.
        #expect(rekeyed.terminals.map(\.name) == ["0:zsh · pane 1", "0:zsh · pane 2", "1:logs: tail"])
    }

    // MARK: Runtime

    private func makeRuntime() async throws -> (MobileSSHComputers, RecordingSSHSink, SSHHostRecord) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hmux-ssh-kinds-\(UUID().uuidString)")
        let computers = MobileSSHComputers(directory: dir)
        let sink = RecordingSSHSink()
        computers.sink = sink
        let host = SSHHostRecord(name: "box", endpoint: SSHEndpoint(host: "127.0.0.1", port: 1, username: "nobody"))
        try await computers.saveHost(host)
        return (computers, sink, host)
    }

    /// A listing merges every kind into one host's rows, each row carrying
    /// its kind in the id and its subtitle; `+` offers every kind before
    /// the host is probed, and the probed set after.
    @Test func listingMergesKindsAndPublishesSubtitles() async throws {
        let (computers, sink, host) = try await makeRuntime()
        #expect(computers.kindAvailability(hostID: host.id).map(\.kind) == [.hmuxTUI, .tmux, .shell])
        #expect(computers.kindAvailability(hostID: host.id).allSatisfy { $0.isAvailable })

        let tmux = StaticProvider(workspaces: [
            MobileSSHWorkspace(id: "work", name: "work", terminals: [MobileSSHTerminal(id: "work/%1", name: "0:zsh")]),
        ])
        let plain = StaticProvider(workspaces: [
            MobileSSHWorkspace(id: "1", name: "Shell 1", terminals: [MobileSSHTerminal(id: "1", name: "Shell 1")]),
        ])
        computers.installProvidersForTesting(tmux: tmux, plain: plain, hostID: host.id)
        await computers.refreshWorkspaces(hostID: host.id)

        let rows = try #require(sink.states.last?.workspaces)
        #expect(rows.map { MobileSSHIdentifier($0.id.rawValue).localID } == ["tmux:work", "shell:1"])
        #expect(rows.map(\.previewText) == ["tmux session", "Shell"])
        #expect(rows[0].terminals.first?.id.rawValue == MobileSSHIdentifier(host: host.id, local: "tmux:work/%1").rawValue)
        #expect(computers.supportsTerminalTabs(workspaceID: rows[0].id.rawValue))
        #expect(!computers.supportsTerminalTabs(workspaceID: rows[1].id.rawValue))

        // Probed: no hmux-tui on this test host, so it is unavailable.
        let kinds = computers.kindAvailability(hostID: host.id)
        #expect(kinds.first { $0.kind == .tmux }?.isAvailable == true)
        #expect(kinds.first { $0.kind == .shell }?.isAvailable == true)
        #expect(kinds.first { $0.kind == .hmuxTUI }?.isAvailable == false)
    }

    /// Terminal queries: the server answers for hmux-tui and tmux surfaces,
    /// the phone for shells, decided per surface by its kind.
    @Test func queryAnswererFollowsTheSurfaceKind() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hmux-ssh-kinds-q-\(UUID().uuidString)")
        let computers = MobileSSHComputers(directory: dir)
        let store = MobileShellComposite(
            isSignedIn: true,
            pairedMacStore: MobileShellDemoContentTests.RecordingPairedMacStore(),
            identityProvider: StaticIdentityProvider(userID: "ssh-kinds-user"),
            teamIDProvider: { "team-a" },
            sshComputers: computers
        )
        let host = UUID()
        func surface(_ local: MobileSSHLocalID) -> String {
            MobileSSHIdentifier(host: host, local: local.rawValue).rawValue
        }
        #expect(store.sshServerAnswersTerminalQueries(surfaceID: surface(.hmuxTUI(session: "main", id: "term_a"))) == true)
        #expect(store.sshServerAnswersTerminalQueries(surfaceID: surface(.tmux("work/%1"))) == true)
        #expect(store.sshServerAnswersTerminalQueries(surfaceID: surface(.shell("1"))) == false)
        #expect(store.sshServerAnswersTerminalQueries(surfaceID: "mac-surface") == nil)
    }
}

/// A provider that lists fixed workspaces.
@MainActor
final class StaticProvider: MobileSSHWorkspaceProvider {
    var workspaces: [MobileSSHWorkspace]

    init(workspaces: [MobileSSHWorkspace]) {
        self.workspaces = workspaces
    }

    func listWorkspaces() async throws -> [MobileSSHWorkspace] { workspaces }
    func createWorkspace() async throws -> MobileSSHWorkspace { throw CancellationError() }
    func closeWorkspace(id: String) async throws { workspaces.removeAll { $0.id == id } }
    func attach(
        terminalID: String,
        columns: Int,
        rows: Int,
        events: @escaping @MainActor (MobileSSHAttachEvent) -> Void
    ) async throws -> any MobileSSHAttachedTerminal {
        throw CancellationError()
    }
}
