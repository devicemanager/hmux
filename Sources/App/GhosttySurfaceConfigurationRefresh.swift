@MainActor
enum GhosttySurfaceConfigurationRefresh {
    nonisolated static let forceRefreshReason = "appDelegate.refreshAfterGhosttyConfigReload"
    nonisolated static let hmuxThemeReloadLegacySource = "distributed.hmux.themes"
    nonisolated static let hmuxThemeReloadPreviewSource = "distributed.hmux.themes.preview"
    nonisolated static let hmuxThemeReloadFinalSource = "distributed.hmux.themes.final"
    nonisolated static let hmuxThemePreviewReloadDebounceMilliseconds = 180

    nonisolated static func hmuxThemeReloadSource(phase: String?) -> String {
        switch phase {
        case "final", "apply":
            return hmuxThemeReloadFinalSource
        case "preview":
            return hmuxThemeReloadPreviewSource
        default:
            return hmuxThemeReloadLegacySource
        }
    }

    nonisolated static func shouldDebounceHmuxThemeReload(source: String) -> Bool {
        switch source {
        case hmuxThemeReloadLegacySource, hmuxThemeReloadPreviewSource:
            return true
        default:
            return false
        }
    }

    nonisolated static func isHmuxThemeReloadSource(_ source: String) -> Bool {
        switch source {
        case hmuxThemeReloadLegacySource, hmuxThemeReloadPreviewSource, hmuxThemeReloadFinalSource:
            return true
        default:
            return false
        }
    }

    static func applyAfterAppConfigReload(
        to surface: ghostty_surface_t?,
        source: String,
        reloadSurfaceConfiguration: (ghostty_surface_t, Bool, String) -> Void,
        applySurfaceColorScheme: () -> Void,
        refreshHostBackground: () -> Void,
        forceRefresh: (String) -> Void
    ) {
        applyConfigurationReload(
            to: surface,
            soft: true,
            source: source,
            redrawReason: forceRefreshReason,
            reloadSurfaceConfiguration: reloadSurfaceConfiguration,
            applySurfaceColorScheme: applySurfaceColorScheme,
            refreshHostBackground: refreshHostBackground,
            forceRefresh: forceRefresh
        )
    }

    static func applyConfigurationReload(
        to surface: ghostty_surface_t?,
        soft: Bool,
        source: String,
        redrawReason: String,
        reloadSurfaceConfiguration: (ghostty_surface_t, Bool, String) -> Void,
        applySurfaceColorScheme: () -> Void,
        refreshHostBackground: () -> Void,
        forceRefresh: (String) -> Void
    ) {
        if let surface {
            reloadSurfaceConfiguration(surface, soft, source)
            // The scheme must resolve against the newly installed config. Applying
            // it to the stale config can emit an old background before the reload,
            // pairing that background with the new foreground (issues #8938, #9588).
            applySurfaceColorScheme()
        }
        refreshHostBackground()
        forceRefresh(redrawReason)
    }
}
