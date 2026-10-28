@testable import HmuxSimulatorUI

actor ImmediateProcessSleeper: SimulatorProcessSleeper {
    private(set) var callCount = 0

    func sleep(for duration: Duration) async throws {
        callCount += 1
    }
}
