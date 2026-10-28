import Foundation

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

final class InMemoryWorkspaceCreateIdempotencyStore:
    TerminalController.WorkspaceCreateIdempotencyPersisting {
    private var operationIDs: [UUID] = []

    func loadOperationIDs() -> [UUID] { operationIDs }

    func saveOperationIDs(_ operationIDs: [UUID]) {
        self.operationIDs = operationIDs
    }
}
