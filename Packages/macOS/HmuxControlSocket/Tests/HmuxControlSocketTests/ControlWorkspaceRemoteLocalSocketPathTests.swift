import Testing
@testable import HmuxControlSocket

struct ControlWorkspaceRemoteLocalSocketPathTests {
    private let controllerSocketPath = "/Users/me/Library/Application Support/hmux/hmux.sock"

    @Test(arguments: ["/tmp/other.sock", "/tmp/hmux.sock", "/var/run/other.sock"])
    func forwardsToTheControllerSocketWhateverPathTheClientSends(requested: String) {
        #expect(
            ControlWorkspaceRemoteLocalSocketPath(
                controllerSocketPath: controllerSocketPath
            ).resolved(requested: requested) == controllerSocketPath
        )
    }

    @Test(arguments: [nil, "", "  \n"] as [String?])
    func leavesForwardingOffWhenTheClientDoesNotAskForIt(requested: String?) {
        #expect(
            ControlWorkspaceRemoteLocalSocketPath(
                controllerSocketPath: controllerSocketPath
            ).resolved(requested: requested) == nil
        )
    }

    @Test(arguments: [nil, "", " "] as [String?])
    func leavesForwardingOffWhenTheControllerHasNoSocket(controllerSocketPath: String?) {
        #expect(
            ControlWorkspaceRemoteLocalSocketPath(
                controllerSocketPath: controllerSocketPath
            ).resolved(requested: "/tmp/other.sock") == nil
        )
    }
}
