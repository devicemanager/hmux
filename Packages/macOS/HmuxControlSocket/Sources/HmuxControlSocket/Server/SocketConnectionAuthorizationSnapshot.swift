internal import HmuxSettings
internal import Foundation

/// Mutable fields protected by ``SocketConnectionAuthorizationState``.
struct SocketConnectionAuthorizationSnapshot: Sendable {
    var accessMode: SocketControlMode = .hmuxOnly
    var isRunning = false
    var passwordFingerprint: Data?
    var generation = SocketConnectionAuthorizationGeneration(
        number: 0,
        revocationSignal: SocketAuthorizationRevocationSignal()
    )
}
