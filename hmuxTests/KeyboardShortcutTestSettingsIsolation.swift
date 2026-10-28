import Foundation

#if canImport(hmux_DEV)
@testable import hmux_DEV
#elseif canImport(hmux)
@testable import hmux
#endif

@MainActor
extension KeyboardShortcutSettings {
    static func installIsolatedTestFileStore(prefix: String) -> KeyboardShortcutSettingsFileStore {
        let original = settingsFileStore
        let settingsFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString).json", isDirectory: false)
        settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            startWatching: false
        )
        return original
    }
}
