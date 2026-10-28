import HMUXMobileCore
@testable import HmuxMobileRPC

struct SlowConnectTimeoutTransportFactory: CmxByteTransportFactory {
    let transport: SlowConnectTimeoutTransport

    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        transport
    }
}
