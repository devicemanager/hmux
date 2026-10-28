import Foundation

/// Cancellation handle for the HMUX host transport.
@_spi(HmuxHostTransport)
public struct HmuxSidebarActionCancellation: Sendable {
    private let cancelAction: @Sendable () -> Void

    /// Creates a cancellation handle.
    /// - Parameter cancel: Work that removes the pending action from the transport.
    public init(_ cancel: @escaping @Sendable () -> Void) {
        self.cancelAction = cancel
    }

    /// Cancels the pending host action if it is still waiting for a reply.
    public func cancel() {
        cancelAction()
    }
}
