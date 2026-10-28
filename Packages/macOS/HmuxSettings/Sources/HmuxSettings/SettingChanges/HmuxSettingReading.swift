import Foundation

/// A settings path as `hmux config get` reports it.
public struct HmuxSettingReading: Sendable, Equatable {
    /// The dotted path that was read.
    public let path: String
    /// The value hmux.json sets, or nil when the key is absent.
    public let configured: HmuxSettingValue?
    /// The value stored outside hmux.json, such as one set in the Settings
    /// window, or nil when there is none.
    public let live: HmuxSettingValue?
    /// The schema default, or nil when the schema declares none.
    public let defaultValue: HmuxSettingValue?

    /// The value hmux uses: the configured value, else the live value, else
    /// the default.
    public var effective: HmuxSettingValue? {
        configured ?? live ?? defaultValue
    }
}

extension JSONConfigStore {
    /// Reads one settings path straight from disk, validated the same way
    /// ``apply(_:)`` validates a write.
    ///
    /// - Parameter liveValues: Where to read the value of a key the file
    ///   doesn't set, as in ``apply(_:liveValues:)``.
    /// - Throws: ``HmuxSettingChangeError`` for an unknown or non-setting
    ///   path, or a read/parse error for an unreadable file.
    public nonisolated func reading(
        at path: String,
        liveValues: HmuxSettingLiveValues = .schemaDefaultsOnly
    ) throws -> HmuxSettingReading {
        let planner = HmuxSettingChangePlanner(liveValues: liveValues)
        let root = try snapshotRoot()
        let jsonPath = try planner.settingPath(path, root: root)
        let configured = jsonPath.lookup(in: root).flatMap(HmuxSettingValue.init(jsonObject:))
        return HmuxSettingReading(
            path: path,
            configured: configured,
            live: configured == nil ? planner.liveValue(at: jsonPath) : nil,
            defaultValue: planner.defaultValue(at: jsonPath).flatMap(HmuxSettingValue.init(jsonObject:))
        )
    }
}
