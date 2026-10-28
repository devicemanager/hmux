import Testing

@testable import HmuxSimulatorWorker

@Suite("Simulator framebuffer publication resilience")
struct SimulatorFramebufferPublicationResilienceTests {
    @Test("Persistent publication failures stop after bounded backoff")
    func persistentFailuresStopAfterBoundedBackoff() {
        var policy = SimulatorFramebufferPublicationFailurePolicy(
            maximumConsecutiveFailureCount: 3,
            initialRetryDelay: .milliseconds(20)
        )

        #expect(policy.retryDelayAfterFailure() == .milliseconds(20))
        #expect(policy.retryDelayAfterFailure() == .milliseconds(40))
        #expect(policy.retryDelayAfterFailure() == nil)

        policy.recordSuccess()
        #expect(policy.retryDelayAfterFailure() == .milliseconds(20))
    }

    @Test("Host adoption drains retired transport bookkeeping")
    func hostAdoptionDrainsRetiredTransportBookkeeping() async {
        let ledger = SimulatorFramebufferRetirementLedger(maximumRetiredNameCount: 2)
        #expect(await ledger.recordRetired("/hmux-sim-frame-first"))
        #expect(await ledger.recordRetired("/hmux-sim-frame-second"))
        let acceptedOverflow = await ledger.recordRetired("/hmux-sim-frame-overflow")
        #expect(!acceptedOverflow)

        #expect(await ledger.count == 2)
        #expect(await ledger.takeRetiredNames() == [
            "/hmux-sim-frame-first",
            "/hmux-sim-frame-second",
        ])
        #expect(await ledger.count == 0)
    }
}
