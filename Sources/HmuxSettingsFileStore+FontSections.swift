import HmuxTerminalCore
import Foundation

/// Parses the hmux-owned font settings that historically lived in config.ghostty.
extension HmuxSettingsFileStore {
    func parseFontSections(
        _ root: [String: Any],
        sourcePath: String,
        snapshot: inout ResolvedSettingsSnapshot
    ) {
        if let sidebar = root["sidebar"] as? [String: Any] {
            if let value = jsonDouble(sidebar["fontSize"]), value.isFinite,
               (Double(GhosttyConfig.minSidebarFontSize)...Double(GhosttyConfig.maxSidebarFontSize)).contains(value) {
                snapshot.managedUserDefaults[HmuxJSONFontSettings.sidebarUserDefaultsKey] = .double(value)
            } else if sidebar.keys.contains("fontSize") {
                logInvalid(HmuxJSONFontSettings.sidebarPath, sourcePath: sourcePath)
                snapshot.invalidManagedUserDefaultKeys.insert(HmuxJSONFontSettings.sidebarUserDefaultsKey)
            }
        }
        if let tabBar = root["surfaceTabBar"] as? [String: Any] {
            if let value = jsonDouble(tabBar["fontSize"]), value.isFinite,
               (Double(GhosttyConfig.minSurfaceTabBarFontSize)...Double(GhosttyConfig.maxSurfaceTabBarFontSize)).contains(value) {
                snapshot.managedUserDefaults[HmuxJSONFontSettings.surfaceTabBarUserDefaultsKey] = .double(value)
            } else if tabBar.keys.contains("fontSize") {
                logInvalid(HmuxJSONFontSettings.surfaceTabBarPath, sourcePath: sourcePath)
                snapshot.invalidManagedUserDefaultKeys.insert(HmuxJSONFontSettings.surfaceTabBarUserDefaultsKey)
            }
        }
    }
}
