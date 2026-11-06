#if os(iOS)
import Testing
@testable import hmuxFeature

/// Cloud needs a hmux account, which a local-only app never has, so the
/// local-only app builds no Cloud controller and shows no Cloud tab.
@Suite struct MobileCloudLocalOnlyTests {
    @Test func cloudIsUnavailableInALocalOnlyBuild() {
        #expect(!MobileCloudComposition.isAvailable(isLocalOnly: true))
        #expect(MobileCloudComposition.isAvailable(isLocalOnly: false))
    }
}
#endif
