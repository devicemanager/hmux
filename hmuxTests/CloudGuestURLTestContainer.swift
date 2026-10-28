import Foundation
#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
final class CloudGuestURLTestContainer: TerminalLinkOpenContainer {
    let terminalLinkContainerDebugName = "cloud-fixture"
    var opened: [URL] = []
    var focus = true
    var accepts = true
    func terminalLinkWorkingDirectory(for sourcePanelId: UUID) -> String? { nil }
    func terminalLinkIsRemoteTerminal(_ sourcePanelId: UUID) -> Bool { true }
    func cloudTerminalLinkTarget(url: URL, sourcePanelId: UUID) -> CloudTerminalLinkTarget? { nil }
    func deferTerminalFileLinkOpen(sourcePanelId: UUID, filePath: String, fallback: @escaping @MainActor @Sendable () -> Void) -> Bool { false }
    func openTerminalBrowserLink(url: URL, sourcePanelId: UUID, focus: Bool) -> Bool {
        self.focus = focus
        opened.append(url)
        return accepts
    }
}
