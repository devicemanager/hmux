import Foundation
@testable import HmuxTerminal

final class FakeHibernationRecorder: AgentHibernationRecording {
    @MainActor
    func recordTerminalInput(workspaceId: UUID, panelId: UUID) {}
}
