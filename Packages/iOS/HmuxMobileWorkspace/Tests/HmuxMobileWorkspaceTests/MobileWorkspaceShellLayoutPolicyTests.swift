import SwiftUI
import Testing

@testable import HmuxMobileWorkspace

@Suite struct MobileWorkspaceShellLayoutPolicyTests {
    @Test func compactHeightUsesStackWorkspaceNavigation() {
        #expect(
            MobileWorkspaceShellLayoutPolicy.usesCompactStack(
                horizontalSizeClass: .regular,
                verticalSizeClass: .compact
            )
        )
        #expect(
            MobileWorkspaceShellLayoutPolicy.usesCompactStack(
                horizontalSizeClass: .compact,
                verticalSizeClass: .regular
            )
        )
        #expect(
            !MobileWorkspaceShellLayoutPolicy.usesCompactStack(
                horizontalSizeClass: .regular,
                verticalSizeClass: .regular
            )
        )
    }
}
