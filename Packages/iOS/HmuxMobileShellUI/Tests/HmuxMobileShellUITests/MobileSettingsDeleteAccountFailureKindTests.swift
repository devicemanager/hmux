#if os(iOS)
import HmuxAuthRuntime
import Testing
@testable import HmuxMobileShellUI

@Suite struct MobileSettingsDeleteAccountFailureKindTests {
    @Test func definitiveDeletedSessionFailuresSignOutAfterAcknowledgement() {
        #expect(DeleteAccountFailureKind.serverCleanupIncomplete.signsOutAfterAcknowledgement)
        #expect(DeleteAccountFailureKind.unauthorized.signsOutAfterAcknowledgement)
        #expect(!DeleteAccountFailureKind.generic.signsOutAfterAcknowledgement)
        #expect(!DeleteAccountFailureKind.connection.signsOutAfterAcknowledgement)
        #expect(!DeleteAccountFailureKind.stackDeleteIncomplete.signsOutAfterAcknowledgement)
        #expect(!DeleteAccountFailureKind.timedOut.signsOutAfterAcknowledgement)
        #expect(!DeleteAccountFailureKind.unknown.signsOutAfterAcknowledgement)
    }

    @Test func accountDeletionUnauthorizedMapsToSignOutRecovery() {
        #expect(DeleteAccountFailureKind(error: AccountDeletionRequestError.unauthorized) == .unauthorized)
        #expect(DeleteAccountFailureKind(error: AuthError.unauthorized) == .unauthorized)
    }

    @Test func accountDeletionTransportTimeoutMapsToTimeoutCopy() {
        #expect(DeleteAccountFailureKind(error: AccountDeletionRequestError.timedOut) == .timedOut)
    }
}
#endif
