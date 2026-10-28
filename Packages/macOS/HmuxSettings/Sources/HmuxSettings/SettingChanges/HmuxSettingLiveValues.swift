import HmuxFoundation
import Foundation

/// Where a setting change finds the value hmux is using for a key that
/// hmux.json doesn't set.
///
/// Most settings are stored in UserDefaults by the Settings window; hmux.json
/// only overrides them. So when the file doesn't name a key, `toggle` and
/// `cycle` must start from the UserDefaults value, not the schema default,
/// or the first press would write the value the user already sees.
public struct HmuxSettingLiveValues: Sendable {
    private let resolve: @Sendable (String) -> HmuxSettingValue?

    /// A resolver backed by a closure from a dotted settings path to its
    /// current value, or nil when it has none.
    public init(resolve: @escaping @Sendable (String) -> HmuxSettingValue?) {
        self.resolve = resolve
    }

    /// No live values: absent keys fall back to the schema default.
    public static let schemaDefaultsOnly = HmuxSettingLiveValues { _ in nil }

    /// Reads UserDefaults-backed settings from the defaults domain
    /// `suiteName`, such as the hmux app's bundle identifier when called from
    /// the CLI. `nil` reads `UserDefaults.standard`, which is the app's own
    /// domain inside the app.
    ///
    /// Only scalar values (true/false, numbers, strings) whose type the
    /// schema allows at that path are used; see ``liveValue(for:storedJSON:schema:)``.
    public static func userDefaults(suiteName: String?) -> HmuxSettingLiveValues {
        let keys = Dictionary(
            SettingCatalog().all.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return HmuxSettingLiveValues { path in
            guard let key = keys[path] else { return nil }
            let defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
            guard let stored = key.jsonValueInUserDefaults(defaults) else { return nil }
            return liveValue(for: path, storedJSON: stored, schema: HmuxConfigSchemaPathLookup())
        }
    }

    /// Settings whose UserDefaults value isn't stored in its hmux.json form.
    /// Each maps the stored value (already in its catalog JSON encoding) to
    /// the hmux.json value. Keep in sync with the hmux.json-to-UserDefaults
    /// mapping in the app's settings file store
    /// (`HmuxSettingsFileStore+AppSection.swift`,
    /// `KeyboardShortcutSettingsFileStore.swift`); the catalog test in
    /// `HmuxSettingChangeTests` fails when a new key needs an entry.
    static let storedValueMappings: [String: @Sendable (Any) -> HmuxSettingValue?] = [
        // Stored as the workspace presentation mode.
        "app.minimalMode": { stored in
            switch stored as? String {
            case "minimal": return .bool(true)
            case "standard": return .bool(false)
            default: return nil
            }
        },
        // Stored as the opposite flag, "close the workspace".
        "app.keepWorkspaceOpenWhenClosingLastSurface": { stored in
            (stored as? Bool).map { .bool(!$0) }
        },
        // Stored as a width, with a negative sentinel for "no cap", which
        // hmux.json spells `false`.
        SessionContentWidthSettings.settingsPath: { stored in
            guard let width = (stored as? NSNumber)?.doubleValue, width.isFinite else { return nil }
            return width < SessionContentWidthSettings.minimumWidth ? .bool(false) : .number(width)
        },
    ]

    /// The hmux.json value for a stored UserDefaults value, or nil when the
    /// stored form can't be trusted to mean the same thing: a non-scalar
    /// value (lists and maps are often stored as text), or a type the schema
    /// doesn't allow at `path`.
    static func liveValue(
        for path: String,
        storedJSON: Any,
        schema: HmuxConfigSchemaPathLookup
    ) -> HmuxSettingValue? {
        if let mapping = storedValueMappings[path] {
            return mapping(storedJSON)
        }
        guard let value = HmuxSettingValue(jsonObject: storedJSON) else { return nil }
        let allowed = schema.declaredTypes(at: path.split(separator: ".").map(String.init))
        switch value {
        case .bool:
            return allowed.contains("boolean") ? value : nil
        case .string:
            return allowed.contains("string") ? value : nil
        case .number(let number):
            if allowed.contains("number") { return value }
            return allowed.contains("integer") && number.rounded() == number ? value : nil
        case .null, .array, .object:
            return nil
        }
    }

    func value(at path: String) -> HmuxSettingValue? {
        resolve(path)
    }
}
