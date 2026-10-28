@testable import HmuxSimulatorWorker

struct ImmediateHIDSleeper: SimulatorHIDSleeping {
    func sleep(for duration: Duration) async throws {}
}
