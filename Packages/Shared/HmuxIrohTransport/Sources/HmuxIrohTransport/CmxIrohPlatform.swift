/// Platform role bound into Iroh registration and pairing credentials.
public enum CmxIrohPlatform: String, Codable, Equatable, Sendable {
    /// A hmux host running on macOS.
    case mac

    /// A hmux mobile client running on iOS.
    case ios
}
