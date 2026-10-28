import HMUXMobileCore
import Foundation
@testable import HmuxIrohTransport

extension CmxIrohProtocolConfiguration {
    static let testApplicationLanes = CmxIrohProtocolConfiguration(
        alpn: Data("hmux/mobile/1".utf8),
        maximumHeaderByteCount: 16 * 1_024,
        maximumConcurrentClientApplicationLaneCount: 16
    )

    static let testRelayOnlyApplicationLanes = CmxIrohProtocolConfiguration(
        alpn: Data("hmux/mobile/1".utf8),
        maximumHeaderByteCount: 16 * 1_024,
        maximumConcurrentClientApplicationLaneCount: 16,
        allowsNATTraversalAfterAdmission: false
    )

    static let testDirectOnlyApplicationLanes = CmxIrohProtocolConfiguration(
        alpn: Data("hmux/mobile/1".utf8),
        maximumHeaderByteCount: 16 * 1_024,
        maximumConcurrentClientApplicationLaneCount: 16,
        allowsNATTraversalAfterAdmission:
            CmxIrohTransportVerificationMode.directOnly
                .allowsNATTraversalAfterAdmission
    )
}
