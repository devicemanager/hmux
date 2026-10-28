import HmuxTerminalCore

/// App-target alias for ``HmuxTerminalCore/GhosttyConfig``, lifted into
/// HmuxTerminalCore in stack D tranche A. Keeps every `GhosttyConfig` call site
/// (and `GhosttyConfig.ColorSchemePreference` / `GhosttyConfig.UserAppearanceConfigSummary`
/// member lookups) byte-identical across the app target.
typealias GhosttyConfig = HmuxTerminalCore.GhosttyConfig
