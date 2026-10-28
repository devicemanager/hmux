import CoreGraphics
import Testing

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
@Suite
struct GhosttyExternalDisplayScalingTests {
    @Test("screen changes reconcile a stale terminal backing scale")
    func screenChangeReconcilesStaleBackingScale() {
        #expect(
            GhosttyNSView.shouldReconcileBackingScale(
                currentScale: 2,
                targetScale: 1
            )
        )
    }

    @Test("screen changes do not re-commit an already matching scale")
    func screenChangeSkipsMatchingBackingScale() {
        #expect(
            !GhosttyNSView.shouldReconcileBackingScale(
                currentScale: 2,
                targetScale: 2
            )
        )
    }
}
