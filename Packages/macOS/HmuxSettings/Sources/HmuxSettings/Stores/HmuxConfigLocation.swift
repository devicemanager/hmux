import Foundation

/// Conventional on-disk locations for the hmux JSON config.
///
/// A small value-typed bundle of URLs. Construct one with an explicit `home`
/// directory and inject it into the parts of the app that need to know where
/// the config file lives. No shared singletons; tests use a custom `home` URL
/// pointing into a temp directory.
///
/// ```swift
/// let locations = HmuxConfigLocation()
/// let store = JSONConfigStore(fileURL: locations.userConfigFile)
/// ```
public struct HmuxConfigLocation: Sendable, Hashable {
    /// The primary hmux config file: `<home>/.config/hmux/hmux.json`.
    public let userConfigFile: URL

    /// The legacy fallback: `<home>/.config/hmux/settings.json`. The app's
    /// settings reader checks this when the primary file is absent.
    public let legacyFallbackFile: URL

    /// Creates a location bundle anchored at the given home directory.
    ///
    /// - Parameter home: The home directory to anchor paths to. Defaults to
    ///   `FileManager.default.homeDirectoryForCurrentUser`. Pass a temp URL
    ///   in tests.
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        // `URL.appending(path:)` is the modern Foundation API (macOS 13+);
        // returns a non-optional URL without the legacy `isDirectory` flag.
        self.userConfigFile = home.appending(path: ".config/hmux/hmux.json")
        self.legacyFallbackFile = home.appending(path: ".config/hmux/settings.json")
    }
}
