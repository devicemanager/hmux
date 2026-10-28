import Testing
import HmuxRemoteSession

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@Suite
struct TabManagerBootstrapTests {
    @MainActor
    @Test
    func appBootstrapManagerDoesNotCreateAWorkspaceOrTerminal() {
        let nativeSSHConnectionBroker = NativeSSHConnectionBroker()
        let manager = TabManager.makeAppBootstrap(
            nativeSSHConnectionBroker: nativeSSHConnectionBroker
        )

        #expect(manager.tabs.isEmpty)
        #expect(manager.selectedWorkspace == nil)
        #expect(manager.selectedSurface == nil)
        #expect(manager.nativeSSHConnectionBroker === nativeSSHConnectionBroker)
    }
}
