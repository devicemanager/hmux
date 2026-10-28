#if DEBUG
import HmuxMobileShellModel

@MainActor
final class HideComputersVerifierIdentityProvider: MobileIdentityProviding {
    let currentUserID: String?

    init(userID: String?) {
        currentUserID = userID
    }
}
#endif
