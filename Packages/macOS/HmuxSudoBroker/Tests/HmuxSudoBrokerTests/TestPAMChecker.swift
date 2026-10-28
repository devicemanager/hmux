@testable import HmuxSudoBroker

struct TestPAMChecker: SudoPAMChecking {
    let enabled: Bool

    func touchIDIsEnabled() -> Bool { enabled }
}
