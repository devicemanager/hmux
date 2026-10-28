extension HMUXCLI {
    /// The surface identity constraints parsed from `hmux restore` or `hmux fork` arguments.
    struct RestoreSelector {
        let surface: String?
        let usesCurrentSurface: Bool
        let kind: String?
        let checkpointID: String?
    }
}
