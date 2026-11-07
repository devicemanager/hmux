#if os(iOS)
import SwiftUI
import Testing
@testable import HmuxMobileShellUI

/// A build with no Cloud (a local-only build) supplies no Cloud tab content,
/// so the tab bar must leave the Cloud tab out instead of showing it empty.
@Suite struct MobileCloudTabVisibilityTests {
    @Test @MainActor func cloudTabIsHiddenWithoutCloudContent() {
        #expect(!MobilePrimaryTab.showsCloudTab(cloudTabContent: nil))
    }

    @Test @MainActor func cloudTabIsShownWithCloudContent() {
        let content = MobileCloudTabContent(content: { EmptyView() }, embedded: { EmptyView() })
        #expect(MobilePrimaryTab.showsCloudTab(cloudTabContent: content))
    }
}
#endif
