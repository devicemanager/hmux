import HmuxMobileRPC
import Testing
@testable import HmuxMobileShell

@Suite
struct MobileShellMacAvailabilityFailureClassifierTests {
    @Test
    func cleanupBlockedRouteIsUnavailableWhileAccountMismatchIsReachable() {
        let classifier = MobileShellMacAvailabilityFailureClassifier()

        #expect(classifier.isAvailabilityFailure(
            MobileShellConnectionError.routeCleanupBlocked
        ))
        #expect(!classifier.isAvailabilityFailure(
            MobileShellConnectionError.accountMismatch("different account")
        ))
    }
}
