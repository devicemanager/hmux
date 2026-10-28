import Foundation

/// Color theme for the Sleepy Mode mascot and scene.
public enum SleepyTheme: String, CaseIterable, Identifiable, Sendable, SettingCodable {
    case hmux
    case blossom
    case mint
    case mono
    case custom
    public var id: String { rawValue }
}
