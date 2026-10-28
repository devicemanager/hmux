struct DockTrustRequest: Identifiable, Sendable {
    var id: String { descriptor.fingerprint }
    let descriptor: HmuxActionTrustDescriptor
    let configPath: String
}
