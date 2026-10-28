import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// Regression coverage for the workspace-group "Edit Group Configuration…"
/// action. The opener must route the hmux config file through the same
/// editor-resolving path the rest of the app uses (so `preferredEditorCommand`
/// is honored) rather than handing it to `NSWorkspace.shared.open`, which
/// routes to the OS default `.json` handler and ignores the hmux setting.
///
/// Before the fix the opener called `NSWorkspace.shared.open(configURL)`
/// directly, so the injected opener was never invoked and this test fails.
@Suite struct SidebarWorkspaceGroupConfigOpenerTests {
    @Test func routesConfigFileThroughInjectedOpener() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("hmux-group-config-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }

        var opened: [URL] = []
        SidebarWorkspaceGroupConfigOpener.openHmuxConfigInEditor(home: home) { opened.append($0) }

        #expect(opened.count == 1)
        let url = try #require(opened.first)
        #expect(url.lastPathComponent == "hmux.json")
        // Resolved beneath the injected home, under .config/hmux.
        #expect(url.path.hasPrefix(home.path))
        #expect(url.deletingLastPathComponent().lastPathComponent == "hmux")

        // The opener materializes an empty config when none exists, scoped to
        // the injected home (no real-filesystem side effects).
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
