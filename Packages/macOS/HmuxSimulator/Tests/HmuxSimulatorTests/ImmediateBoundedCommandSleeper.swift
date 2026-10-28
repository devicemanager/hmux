import Foundation
@testable import HmuxSimulator

struct ImmediateBoundedCommandSleeper: SimulatorWorkerSleeping {
    func sleep(for duration: Duration) async throws {}
}
