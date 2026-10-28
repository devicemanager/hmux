import HmuxMobileShellModel
@testable import HmuxMobileShell

struct SecondaryAuthorityIdlePresence: PresenceSubscribing {
    func subscribe() async throws
        -> AsyncThrowingStream<PresenceUpdate, any Error> {
        AsyncThrowingStream { _ in }
    }
}
