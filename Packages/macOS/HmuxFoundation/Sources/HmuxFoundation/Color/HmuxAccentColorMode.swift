public import Foundation

/// Which color hmux-drawn chrome uses as its accent (`app.accentColor`).
public enum HmuxAccentColorMode: String, CaseIterable, Sendable {
    /// hmux's own blue, the same in every macOS accent setting.
    case hmux
    /// The macOS accent color from System Settings > Appearance.
    case system
    /// A user-chosen color stored under ``customHexUserDefaultsKey``.
    case custom

    /// UserDefaults key storing the raw value.
    public static let userDefaultsKey = "appAccentColor"

    /// UserDefaults key storing the `#RRGGBB` color for ``custom``.
    public static let customHexUserDefaultsKey = "appAccentColorCustomHex"

    /// Mode used when nothing valid is stored.
    public static let defaultValue: HmuxAccentColorMode = .hmux

    /// Reads the stored mode, falling back to ``defaultValue`` for a missing
    /// or unrecognized value. Reads the key directly so drawing code can call
    /// it without building the settings catalog.
    public static func stored(in defaults: UserDefaults = .standard) -> HmuxAccentColorMode {
        HmuxAccentColorMode(rawValue: defaults.string(forKey: userDefaultsKey) ?? "") ?? defaultValue
    }

    /// Reads the stored custom color, or `nil` when it is missing or not a
    /// valid `#RRGGBB` hex.
    public static func storedCustomHex(in defaults: UserDefaults = .standard) -> String? {
        normalizedCustomHex(defaults.string(forKey: customHexUserDefaultsKey))
    }

    /// Uppercased `#RRGGBB` form of a 6-digit hex, or `nil` when invalid.
    public static func normalizedCustomHex(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var digits = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit) else { return nil }
        return "#" + digits.uppercased()
    }

    /// The `app.accentColor` value in hmux.json: `"hmux"`, `"system"`, or
    /// the `#RRGGBB` color for ``custom``. `nil` for ``custom`` without a
    /// valid color, which hmux.json cannot express.
    public static func settingsFileValue(mode: HmuxAccentColorMode, customHex: String?) -> String? {
        switch mode {
        case .hmux, .system:
            return mode.rawValue
        case .custom:
            return normalizedCustomHex(customHex)
        }
    }

    /// Parses an `app.accentColor` value from hmux.json. A `#RRGGBB` hex
    /// selects ``custom`` with that color. The bare `"custom"` is rejected
    /// because it carries no color.
    public static func parseSettingsFileValue(_ raw: String) -> (mode: HmuxAccentColorMode, customHex: String?)? {
        if raw.hasPrefix("#") {
            guard let hex = normalizedCustomHex(raw) else { return nil }
            return (.custom, hex)
        }
        guard let mode = HmuxAccentColorMode(rawValue: raw), mode != .custom else { return nil }
        return (mode, nil)
    }
}
