import HmuxCloud
import Foundation
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

/// Regression coverage for the post-#12505 Cloud startup path.
@Suite("Cloud terminal startup latency")
struct CloudTerminalStartupLatencyTests {
    @Test
    func terminalCreationFailuresKeepTheirKnownCause() {
        #expect(CloudDiagnosticFailure.classify(HmuxTuiSurfaceProvider.ProviderError.remoteTabNotFound("tab_source")) == .notFound)
        #expect(CloudDiagnosticFailure.classify(HmuxTuiSurfaceProvider.ProviderError.invalidSnapshot("machine")) == .response)
        #expect(CloudDiagnosticFailure.classify(HmuxTuiSurfaceProvider.ProviderError.terminalAttachTimedOut(
            terminalID: "term_created", failure: .transportUnavailable
        )) == .timeout)
    }

    @Test @MainActor
    func unresolvedSurfaceCannotStartAnAttachStream() {
        let session = CloudTuiManualMirrorSession(
            machineID: "machine",
            terminalID: "term_new-machine",
            remoteSurfaceID: 0,
            onNeedsReconnect: {}
        )
        defer { session.stop() }

        session.reconnect(socketPath: "/tmp/hmux-unresolved-startup.sock")

        #expect(session.phase == .idle)
    }
}
