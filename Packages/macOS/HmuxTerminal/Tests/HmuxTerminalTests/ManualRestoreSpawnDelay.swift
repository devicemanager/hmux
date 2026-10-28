@testable import HmuxTerminal

@MainActor
final class ManualRestoreSpawnDelay: TerminalSurfaceRestoreSpawnDelayCancelling {
    func cancel() {}
}
