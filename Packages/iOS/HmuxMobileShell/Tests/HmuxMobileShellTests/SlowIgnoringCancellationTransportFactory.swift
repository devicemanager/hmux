import HMUXMobileCore
import HmuxMobileRPC

struct SlowIgnoringCancellationTransportFactory: CmxByteTransportFactory {
    func makeTransport(for route: CmxAttachRoute) throws -> any CmxByteTransport {
        SlowIgnoringCancellationTransport()
    }
}
