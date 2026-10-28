import Foundation
@testable import HmuxGit

actor TestWorkspaceChangesClock: WorkspaceChangesClock {
    private var instant: Duration = .zero

    func now() -> Duration {
        instant
    }

    func advance(by duration: Duration) {
        instant += duration
    }
}
