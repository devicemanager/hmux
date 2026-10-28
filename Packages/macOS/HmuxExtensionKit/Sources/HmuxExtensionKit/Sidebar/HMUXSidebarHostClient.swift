import Foundation

@_spi(HmuxHostTransport)
/// Host-side callbacks used by the sidebar XPC bridge.
public struct HmuxSidebarHostClient: Sendable {
    /// Returns the latest host snapshot that should be sent to an extension.
    public var snapshot: @Sendable () async throws -> HmuxSidebarSnapshot

    /// Dispatches a sidebar action from an extension into HMUX.
    public var dispatch: @Sendable (HmuxSidebarAction) async throws -> HmuxSidebarActionResult

    /// Creates a host client from snapshot and action-dispatch closures.
    public init(
        snapshot: @escaping @Sendable () async throws -> HmuxSidebarSnapshot,
        dispatch: @escaping @Sendable (HmuxSidebarAction) async throws -> HmuxSidebarActionResult
    ) {
        self.snapshot = snapshot
        self.dispatch = dispatch
    }
}
