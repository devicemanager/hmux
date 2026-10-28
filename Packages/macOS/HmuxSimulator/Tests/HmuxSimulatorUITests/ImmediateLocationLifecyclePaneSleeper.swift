@testable import HmuxSimulatorUI

struct ImmediateLocationLifecyclePaneSleeper: SimulatorProcessSleeper {
    func sleep(for duration: Duration) async throws {}
}
