#if os(iOS)
@testable import HmuxMobileBrowserStream
import HmuxMobileCamera
import HmuxMobileSimulatorStream
import HmuxMobileSupport
import HmuxMobileTerminal
import Testing

@testable import hmuxFeature

@Suite struct MobileSessionReplayMaskingTests {
    /// Pins the privacy contract: every content surface that renders through
    /// Metal, video, or raw layer pixels must stay in the session-replay mask
    /// list. Removing one silently unmasks that surface in uploaded replays.
    @Test func maskListCoversEveryContentSurface() {
        let masked = MobileSessionReplayMasking().maskedViewClasses

        #expect(masked.contains { $0 == GhosttySurfaceView.self })
        #expect(masked.contains { $0 == BrowserStreamContentView.self })
        #expect(masked.contains { $0 == SimStreamDisplayView.self })
        #expect(masked.contains { $0 == CameraPreviewHostView.self })
        #expect(masked.contains { $0 == MobileReplayPrivacyMaskView.self })
        #expect(masked.count == 5)
    }
}
#endif
