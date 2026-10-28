import Foundation
@preconcurrency import Network

/// One path observer for the VM client. The actor owns the mutable
/// Network.framework monitor; only its sendable stream crosses the actor
/// boundary, and it never protects domain state or runs UI work.
actor CloudReadNetworkMonitor {
    private let monitor: NWPathMonitor
    public nonisolated let updates: AsyncStream<Bool>

    public init() {
        let monitor = NWPathMonitor()
        self.monitor = monitor
        let (updates, continuation) = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.updates = updates
        monitor.pathUpdateHandler = { continuation.yield($0.status != .unsatisfied) }
        continuation.onTermination = { _ in monitor.cancel() }
        monitor.start(queue: DispatchQueue(label: "hmux.cloud.read-network"))
    }

    deinit { monitor.cancel() }
}

extension Notification.Name {
    static let hmuxCloudReadNetworkChanged = Notification.Name("hmux.cloud.readNetworkChanged")
    static let hmuxCloudReadNetworkRecovered = Notification.Name("hmux.cloud.readNetworkRecovered")
}
