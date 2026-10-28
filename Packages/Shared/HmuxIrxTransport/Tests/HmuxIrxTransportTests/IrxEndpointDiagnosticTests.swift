import Foundation
import Testing

@testable import HmuxIrxTransport

@Suite struct IrxEndpointDiagnosticTests {
    @Test func foundationPresentationKeepsTheNativeRelayDiagnosis() {
        let message = "Relay connection to relay.example.test failed: UnknownIssuer."
        let error: any Error = IrxEndpointError.bindFailed(message)
        #expect(error.localizedDescription == message)
    }
}
