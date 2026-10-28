import Foundation
@testable import HmuxWorkspaces

@MainActor
final class ReadCostStubTab: WorkspaceTabRepresenting {
    let id = UUID()
    var groupId: UUID?
    var isPinned = false
    var currentDirectory = "/tmp"
}
