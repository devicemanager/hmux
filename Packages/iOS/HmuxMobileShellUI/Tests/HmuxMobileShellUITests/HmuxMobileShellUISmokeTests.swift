import Testing
@testable import HmuxMobileShellUI

@Suite struct HmuxMobileShellUISmokeTests {
    @Test @MainActor func workspaceSettingsUsesConventionalSystemIcon() {
        #expect(MobileWorkspaceSettingsIcon.systemName == "gearshape")
    }
}
