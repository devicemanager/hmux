import Foundation

/// Build-level switch for a phone app that talks only to the owner's Macs
/// over their private network: no cmux account, relays, presence, or
/// telemetry.
///
/// The value is baked into Info.plist by the `LocalOnly` build configuration,
/// so Swift packages read it at runtime instead of through a compile flag the
/// app target's xcconfig cannot pass to them.
public enum CmxLocalOnlyMode {
    /// Info.plist key holding `YES` in a local-only build.
    public static let infoPlistKey = "CMUXLocalOnly"

    /// Whether `bundle` was built as a local-only app.
    public static func isEnabled(in bundle: Bundle = .main) -> Bool {
        switch bundle.object(forInfoDictionaryKey: infoPlistKey) {
        case let value as Bool:
            return value
        case let value as String:
            return ["yes", "true", "1"].contains(value.lowercased())
        default:
            return false
        }
    }
}
