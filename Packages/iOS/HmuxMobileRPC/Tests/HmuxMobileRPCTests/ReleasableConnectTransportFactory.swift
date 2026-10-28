import HMUXMobileCore
@testable import HmuxMobileRPC

struct ReleasableConnectTransportFactory: CmxByteTransportFactory {
    let transport: ReleasableConnectTransport

    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        transport
    }
}
