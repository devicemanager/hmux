#if os(iOS)
import HmuxMobileCloud
import Testing
@testable import HmuxMobileCloudUI

@Suite struct CloudSystemVPNSectionTests {
    @Test func toggleIsDisabledDuringEveryTransitionPhase() {
        let phases: [CloudSystemVPNPhase] = [.preparing, .connecting, .disconnecting]

        for phase in phases {
            let section = CloudSystemVPNSection(
                phase: phase,
                isAvailable: true,
                enable: {},
                disable: {},
                retry: {}
            )
            #expect(section.isToggleDisabled)
        }
    }

    @Test func toggleStaysEnabledWhenStableAndAvailable() {
        let section = CloudSystemVPNSection(
            phase: .connected,
            isAvailable: true,
            enable: {},
            disable: {},
            retry: {}
        )

        #expect(!section.isToggleDisabled)
    }
}
#endif
