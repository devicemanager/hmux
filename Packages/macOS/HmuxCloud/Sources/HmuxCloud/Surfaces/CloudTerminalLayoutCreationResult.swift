import HmuxSurfaceCatalogModel

/// The daemon's creation receipt and the source snapshot's workspace identity.
public struct CloudTerminalLayoutCreationResult: Sendable {
    public init(
        created: HmuxTuiSnapshotParser.CreatedTerminalPath,
        workspaceID: String
    ) {
        self.created = created
        self.workspaceID = workspaceID
    }

    public let created: HmuxTuiSnapshotParser.CreatedTerminalPath
    public let workspaceID: String
}
