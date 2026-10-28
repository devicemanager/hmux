import HmuxCore
import HmuxRemoteWorkspace

/// Hands the broker a fresh ``NeverReadyProxyTunnel`` for every restart.
struct NeverReadyProxyTunnelProvider: RemoteProxyTunnelProviding {
    func makeTunnel(
        configuration: WorkspaceRemoteConfiguration,
        remotePath: String,
        localPort: Int,
        credential: BrowserProxyCredential,
        onFatalError: @escaping @Sendable (String) -> Void
    ) -> any RemoteProxyTunneling {
        NeverReadyProxyTunnel()
    }
}
