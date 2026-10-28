import HmuxMobileShellModel
@testable import HmuxMobileShell

struct IdlePresence: PresenceSubscribing {
    func subscribe() async throws
        -> AsyncThrowingStream<PresenceUpdate, any Error> {
        AsyncThrowingStream { _ in }
    }
}
