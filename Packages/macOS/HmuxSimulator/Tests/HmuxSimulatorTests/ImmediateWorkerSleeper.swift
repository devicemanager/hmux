import Foundation
@testable import HmuxSimulator

struct ImmediateWorkerSleeper: SimulatorWorkerSleeping {
    func sleep(for duration: Duration) async throws {}
}
