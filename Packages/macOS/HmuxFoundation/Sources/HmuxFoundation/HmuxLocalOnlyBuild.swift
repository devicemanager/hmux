public import Foundation

/// Build-level switch for a private Mac build that keeps to the owner's own
/// machines: no hmux account, Cloud, Iroh relays, auto-update or telemetry.
/// iPhones pair with it over the Tailscale TCP route using local pairing codes.
///
/// `scripts/build-local-only-mac.sh` bakes `HMUXLocalOnly = YES` into the app's
/// Info.plist; release and development builds never carry it.
public enum HmuxLocalOnlyBuild {
    /// Info.plist key holding `YES` in a local-only build.
    public static let infoPlistKey = "HMUXLocalOnly"

    /// Whether `bundle` was built as a local-only app.
    public static func isEnabled(in bundle: Bundle) -> Bool {
        switch bundle.object(forInfoDictionaryKey: infoPlistKey) {
        case let value as Bool:
            return value
        case let value as String:
            return ["yes", "true", "1"].contains(value.lowercased())
        default:
            return false
        }
    }

    /// Whether the running app is a local-only build. Fixed for the process.
    public static let isEnabled: Bool = isEnabled(in: .main)
}
